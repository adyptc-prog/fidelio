package app.sayitapp.fidelio

import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

class FidelioBackupWorker(
    private val appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val folderUriText = appContext
            .getSharedPreferences(BACKUP_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_BACKUP_FOLDER_URI, null)
            ?: return Result.success() // No folder selected — skip silently

        return try {
            val dbFile = databasePath()
            if (!dbFile.isFile) return Result.success()

            val treeUri = Uri.parse(folderUriText)
            val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                DocumentsContract.getTreeDocumentId(treeUri),
            )

            checkpointDatabase(dbFile)

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).apply {
                timeZone = TimeZone.getDefault()
            }.format(Date())

            val backupName = "fidelio_auto_${timestamp}${BACKUP_EXTENSION}"

            val backupUri = DocumentsContract.createDocument(
                appContext.contentResolver,
                documentUri,
                "application/octet-stream",
                backupName,
            ) ?: return Result.failure()

            appContext.contentResolver.openOutputStream(backupUri, "w")?.use { output ->
                dbFile.inputStream().use { input -> input.copyTo(output) }
            } ?: return Result.failure()

            val checksum = sha256(dbFile.readBytes())

            val metadataUri = DocumentsContract.createDocument(
                appContext.contentResolver,
                documentUri,
                "application/json",
                "$backupName.json",
            )
            if (metadataUri != null) {
                val metadata = JSONObject()
                    .put("backupId", "auto-$timestamp")
                    .put("createdAt", System.currentTimeMillis())
                    .put("fileName", backupName)
                    .put("checksum", checksum)
                    .put("formatVersion", 1)
                    .put("autoBackup", true)
                appContext.contentResolver.openOutputStream(metadataUri, "w")?.use { output ->
                    output.write(metadata.toString(2).toByteArray(Charsets.UTF_8))
                }
            }

            Result.success()
        } catch (_: Exception) {
            Result.failure()
        }
    }

    private fun databasePath(): File {
        val dataRoot = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            appContext.dataDir
        } else {
            appContext.filesDir.parentFile ?: appContext.filesDir
        }
        return File(File(dataRoot, "app_flutter"), "local_loyalty.sqlite")
    }

    private fun checkpointDatabase(dbFile: File) {
        if (!dbFile.isFile) return
        try {
            android.database.sqlite.SQLiteDatabase.openDatabase(
                dbFile.absolutePath, null,
                android.database.sqlite.SQLiteDatabase.OPEN_READWRITE,
            ).use { db ->
                db.rawQuery("PRAGMA wal_checkpoint(FULL)", null).use { it.moveToFirst() }
            }
        } catch (_: Exception) {}
    }

    private fun sha256(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString("") { "%02x".format(it) }
    }

    companion object {
        private const val BACKUP_PREFS_NAME = "fidelio_backup_prefs"
        private const val KEY_BACKUP_FOLDER_URI = "backup_folder_uri"
        private const val BACKUP_EXTENSION = ".fideliobackup"
        private const val WORK_NAME = "fidelio_daily_backup"

        fun schedule(context: Context) {
            val now = Calendar.getInstance()
            val nextMidnight = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_YEAR, 1)
            }
            val initialDelay = nextMidnight.timeInMillis - now.timeInMillis

            val request = PeriodicWorkRequestBuilder<FidelioBackupWorker>(1, TimeUnit.DAYS)
                .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }
    }
}
