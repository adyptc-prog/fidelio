package app.sayitapp.fidelio

import android.content.ComponentName
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.cardemulation.CardEmulation
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.nio.ByteBuffer
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.RSAPublicKeySpec
import java.math.BigInteger
import android.util.Base64

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {
    private var pendingReadResult: MethodChannel.Result? = null
    private var pendingReceiveResult: MethodChannel.Result? = null
    private var pendingSendResult: MethodChannel.Result? = null
    private var pendingLicensePickResult: MethodChannel.Result? = null
    private var pendingBackupFolderResult: MethodChannel.Result? = null
    private var pendingRestorePickResult: MethodChannel.Result? = null
    private var pendingSendPayload: ByteArray? = null
    private var nfcAdapter: NfcAdapter? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val readTimeout = Runnable {
        finishActiveReaderWithError("NFC_TIMEOUT", "No Fidelio NFC device was detected.")
    }
    private val receiveTimeout = Runnable {
        finishReceiveWithError("NFC_TIMEOUT", "No NFC payload was received.")
    }
    private val payloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != FidelioHostApduService.ACTION_PAYLOAD_RECEIVED) {
                return
            }
            finishReceiveWithSuccess(FidelioNfcPayloadStore.getPayload(applicationContext))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        FidelioBackupWorker.schedule(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(isNfcAvailable())
                "sharePayload" -> sharePayload(call, result)
                "readPayload" -> readPayload(result)
                "sendPayload" -> sendPayload(call, result)
                "receivePayload" -> receivePayload(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LICENSE_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkLicense" -> checkLicense(call, result)
                "pickLicenseFile" -> pickLicenseFile(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKUP_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickBackupFolder" -> pickBackupFolder(result)
                "getBackupFolder" -> result.success(getBackupFolderUri())
                "listBackups" -> listBackups(result)
                "createBackup" -> createBackup(call, result)
                "restoreBackup" -> restoreBackup(call, result)
                "pickAndRestoreBackup" -> pickAndRestoreBackup(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_LICENSE_REQUEST_CODE) {
            if (requestCode == PICK_BACKUP_FOLDER_REQUEST_CODE) {
                handleBackupFolderResult(resultCode, data)
            }
            if (requestCode == PICK_RESTORE_BACKUP_REQUEST_CODE) {
                handleRestoreBackupResult(resultCode, data)
            }
            return
        }

        val result = pendingLicensePickResult ?: return
        pendingLicensePickResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.error("LICENSE_PICK_CANCELLED", "No license file was selected.", null)
            return
        }

        try {
            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, flags and Intent.FLAG_GRANT_READ_URI_PERMISSION)
            getSharedPreferences(LICENSE_PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_LICENSE_URI, uri.toString())
                .apply()
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("LICENSE_PICK_FAILED", error.message ?: error.toString(), null)
        }
    }

    override fun onTagDiscovered(tag: Tag?) {
        val isoDep = tag?.let { IsoDep.get(it) }
        if (isoDep == null) {
            finishActiveReaderWithError("UNSUPPORTED_TAG", "The other device does not expose Fidelio NFC access.")
            return
        }

        try {
            isoDep.connect()
            isoDep.timeout = 5000
            requireStatusOk(isoDep.transceive(SELECT_AID_COMMAND))

            val sendPayload = pendingSendPayload
            if (pendingSendResult != null && sendPayload != null) {
                sendPayloadToPeer(isoDep, sendPayload)
                finishSendWithSuccess()
                return
            }

            val infoResponse = isoDep.transceive(GET_INFO_COMMAND)
            requireStatusOk(infoResponse)
            val payloadLength = ByteBuffer.wrap(infoResponse.copyOfRange(0, 4)).int
            if (payloadLength <= 0 || payloadLength > MAX_PAYLOAD_SIZE) {
                throw IllegalStateException("Invalid NFC payload size.")
            }

            val output = ByteArrayOutputStream(payloadLength)
            var offset = 0
            while (offset < payloadLength) {
                val chunkSize = minOf(MAX_CHUNK_SIZE, payloadLength - offset)
                val response = isoDep.transceive(readCommand(offset, chunkSize))
                requireStatusOk(response)
                val chunk = response.copyOfRange(0, response.size - 2)
                output.write(chunk)
                offset += chunk.size
            }

            finishReadWithSuccess(output.toByteArray().toString(Charsets.UTF_8))
        } catch (error: Exception) {
            finishActiveReaderWithError("NFC_FAILED", error.message ?: error.toString())
        } finally {
            try {
                isoDep.close()
            } catch (_: Exception) {
            }
        }
    }

    private fun sharePayload(call: MethodCall, result: MethodChannel.Result) {
        val payload = call.arguments as? String
        if (payload.isNullOrBlank()) {
            result.error("INVALID_PAYLOAD", "The NFC payload is empty.", null)
            return
        }
        if (!isHceAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC card emulation is not available on this Android device.", null)
            return
        }

        FidelioNfcPayloadStore.setPayload(applicationContext, payload)
        setPreferredHceService()
        result.success(null)
    }

    private fun readPayload(result: MethodChannel.Result) {
        if (!isNfcAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC is not available or enabled on this Android device.", null)
            return
        }
        if (pendingReadResult != null) {
            result.error("NFC_BUSY", "An NFC read is already in progress.", null)
            return
        }

        pendingReadResult = result
        mainHandler.postDelayed(readTimeout, READ_TIMEOUT_MS)
        enableReaderMode()
    }

    private fun sendPayload(call: MethodCall, result: MethodChannel.Result) {
        val payload = call.arguments as? String
        if (payload.isNullOrBlank()) {
            result.error("INVALID_PAYLOAD", "The NFC payload is empty.", null)
            return
        }
        if (!isNfcAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC is not available or enabled on this Android device.", null)
            return
        }
        if (pendingSendResult != null || pendingReadResult != null) {
            result.error("NFC_BUSY", "An NFC operation is already in progress.", null)
            return
        }

        pendingSendPayload = payload.toByteArray(Charsets.UTF_8)
        pendingSendResult = result
        mainHandler.postDelayed(readTimeout, READ_TIMEOUT_MS)
        enableReaderMode()
    }

    private fun receivePayload(result: MethodChannel.Result) {
        if (!isHceAvailable()) {
            result.error("NFC_UNAVAILABLE", "NFC card emulation is not available on this Android device.", null)
            return
        }
        if (pendingReceiveResult != null) {
            result.error("NFC_BUSY", "An NFC receive is already in progress.", null)
            return
        }

        FidelioNfcPayloadStore.startReceive(applicationContext)
        setPreferredHceService()
        pendingReceiveResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                payloadReceiver,
                IntentFilter(FidelioHostApduService.ACTION_PAYLOAD_RECEIVED),
                RECEIVER_NOT_EXPORTED,
            )
        } else {
            registerReceiver(
                payloadReceiver,
                IntentFilter(FidelioHostApduService.ACTION_PAYLOAD_RECEIVED),
            )
        }
        mainHandler.postDelayed(receiveTimeout, READ_TIMEOUT_MS)
    }

    private fun enableReaderMode() {
        nfcAdapter?.enableReaderMode(
            this,
            this,
            NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS,
            null,
        )
    }

    private fun isNfcAvailable(): Boolean {
        val adapter = nfcAdapter ?: return false
        return adapter.isEnabled
    }

    private fun isHceAvailable(): Boolean {
        return isNfcAvailable() &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)
    }

    private fun setPreferredHceService() {
        val adapter = nfcAdapter ?: return
        val cardEmulation = CardEmulation.getInstance(adapter)
        val service = ComponentName(this, FidelioHostApduService::class.java)
        cardEmulation.setPreferredService(this, service)
    }

    private fun finishReadWithSuccess(payload: String) {
        val result = pendingReadResult ?: return
        pendingReadResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.success(payload)
        }
    }

    private fun finishSendWithSuccess() {
        val result = pendingSendResult ?: return
        pendingSendResult = null
        pendingSendPayload = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.success(null)
        }
    }

    private fun finishReadWithError(code: String, message: String) {
        val result = pendingReadResult ?: return
        pendingReadResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.error(code, message, null)
        }
    }

    private fun finishActiveReaderWithError(code: String, message: String) {
        if (pendingSendResult != null) {
            finishSendWithError(code, message)
            return
        }
        finishReadWithError(code, message)
    }

    private fun finishSendWithError(code: String, message: String) {
        val result = pendingSendResult ?: return
        pendingSendResult = null
        pendingSendPayload = null
        runOnUiThread {
            mainHandler.removeCallbacks(readTimeout)
            nfcAdapter?.disableReaderMode(this)
            result.error(code, message, null)
        }
    }

    private fun finishReceiveWithSuccess(payload: String) {
        val result = pendingReceiveResult ?: return
        pendingReceiveResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(receiveTimeout)
            try {
                unregisterReceiver(payloadReceiver)
            } catch (_: Exception) {
            }
            result.success(payload)
        }
    }

    private fun finishReceiveWithError(code: String, message: String) {
        val result = pendingReceiveResult ?: return
        pendingReceiveResult = null
        runOnUiThread {
            mainHandler.removeCallbacks(receiveTimeout)
            try {
                unregisterReceiver(payloadReceiver)
            } catch (_: Exception) {
            }
            result.error(code, message, null)
        }
    }

    private fun requireStatusOk(response: ByteArray) {
        if (response.size < 2 ||
            response[response.size - 2] != 0x90.toByte() ||
            response[response.size - 1] != 0x00.toByte()
        ) {
            throw IllegalStateException("The other device rejected the NFC request.")
        }
    }

    private fun readCommand(offset: Int, length: Int): ByteArray {
        return byteArrayOf(
            0x80.toByte(),
            0xB0.toByte(),
            ((offset ushr 8) and 0xff).toByte(),
            (offset and 0xff).toByte(),
            length.toByte(),
        )
    }

    private fun sendPayloadToPeer(isoDep: IsoDep, payload: ByteArray) {
        requireStatusOk(isoDep.transceive(writeInitCommand(payload.size)))
        var offset = 0
        while (offset < payload.size) {
            val chunkLength = minOf(MAX_CHUNK_SIZE, payload.size - offset)
            val chunk = payload.copyOfRange(offset, offset + chunkLength)
            requireStatusOk(isoDep.transceive(writeChunkCommand(chunk)))
            offset += chunkLength
        }
        requireStatusOk(isoDep.transceive(WRITE_COMMIT_COMMAND))
    }

    private fun writeInitCommand(length: Int): ByteArray {
        return byteArrayOf(
            0x80.toByte(),
            0xD0.toByte(),
            0x00.toByte(),
            0x00.toByte(),
            0x04.toByte(),
        ) + ByteBuffer.allocate(4).putInt(length).array()
    }

    private fun writeChunkCommand(chunk: ByteArray): ByteArray {
        return byteArrayOf(
            0x80.toByte(),
            0xD1.toByte(),
            0x00.toByte(),
            0x00.toByte(),
            chunk.size.toByte(),
        ) + chunk
    }

    private fun checkLicense(call: MethodCall, result: MethodChannel.Result) {
        val businessId = call.argument<String>("businessId").orEmpty()
        if (businessId.isBlank()) {
            result.success(licenseResult("missing", "Business profile is not configured.", null))
            return
        }

        val licenseSource = readSelectedLicense() ?: readAutomaticLicense()
        if (licenseSource == null) {
            result.success(licenseResult("missing", "USB license was not found.", null))
            return
        }

        try {
            val root = JSONObject(licenseSource.content)
            val payload = root.getJSONObject("payload")
            val signature = root.optString("signature")
            val licenseBusinessId = payload.optString("businessId")
            val licenseStickId = payload.optString("stickId")
            val isLifetime = payload.optBoolean("isLifetime", false)
            val actualStickId = licenseSource.stickId

            if (licenseBusinessId != businessId) {
                result.success(licenseResult("invalid", "License belongs to another business.", licenseSource.path))
                return
            }
            if (actualStickId != null && actualStickId != licenseStickId) {
                result.success(licenseResult("invalid", "License does not match this USB stick.", licenseSource.path))
                return
            }
            if (!isLifetime) {
                result.success(licenseResult("invalid", "License is not lifetime.", licenseSource.path))
                return
            }
            if (!verifyLicenseSignature(payload, signature)) {
                result.success(licenseResult("invalid", "License signature is invalid.", licenseSource.path))
                return
            }

            val data = HashMap<String, Any?>()
            data["status"] = "active"
            data["message"] = "Lifetime license active."
            data["path"] = licenseSource.path
            data["licenseId"] = payload.optString("licenseId")
            data["stickId"] = payload.optString("stickId")
            result.success(data)
        } catch (error: Exception) {
            result.success(licenseResult("invalid", error.message ?: error.toString(), licenseSource.path))
        }
    }

    private fun pickLicenseFile(result: MethodChannel.Result) {
        if (pendingLicensePickResult != null) {
            result.error("LICENSE_PICK_BUSY", "A license picker is already open.", null)
            return
        }

        pendingLicensePickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/*", "application/octet-stream"))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, PICK_LICENSE_REQUEST_CODE)
    }

    private fun readSelectedLicense(): LicenseSource? {
        val uriText = getSharedPreferences(LICENSE_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LICENSE_URI, null)
            ?: return null
        return try {
            val uri = Uri.parse(uriText)
            val content = contentResolver.openInputStream(uri)?.use { input ->
                input.reader(Charsets.UTF_8).readText()
            } ?: return null
            LicenseSource(content = content, path = uriText, stickId = null)
        } catch (_: Exception) {
            null
        }
    }

    private fun readAutomaticLicense(): LicenseSource? {
        val licenseFile = findLicenseFile() ?: return null
        val stickIdFile = File(licenseFile.parentFile, "stick_id.txt")
        val stickId = if (stickIdFile.isFile) {
            stickIdFile.readText(Charsets.UTF_8).trim()
        } else {
            null
        }
        return LicenseSource(
            content = licenseFile.readText(Charsets.UTF_8),
            path = licenseFile.absolutePath,
            stickId = stickId,
        )
    }

    private fun findLicenseFile(): File? {
        val candidates = mutableListOf<File>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val storageManager = getSystemService(StorageManager::class.java)
            for (volume in storageManager.storageVolumes) {
                if (!volume.isRemovable) {
                    continue
                }
                val directory = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    volume.directory
                } else {
                    null
                }
                if (directory != null) {
                    candidates.add(File(directory, LICENSE_RELATIVE_PATH))
                }
            }
        }

        val storageRoot = File("/storage")
        storageRoot.listFiles()?.forEach { volume ->
            if (volume.name != "emulated" && volume.name != "self") {
                candidates.add(File(volume, LICENSE_RELATIVE_PATH))
            }
        }

        return candidates.firstOrNull { it.isFile && it.canRead() }
    }

    private fun verifyLicenseSignature(payload: JSONObject, signatureBase64: String): Boolean {
        if (signatureBase64.isBlank()) {
            return false
        }
        val canonical = canonicalLicensePayload(payload)
        val signatureBytes = Base64.decode(signatureBase64, Base64.DEFAULT)
        val modulus = BigInteger(1, Base64.decode(LICENSE_PUBLIC_MODULUS, Base64.DEFAULT))
        val exponent = BigInteger(1, Base64.decode(LICENSE_PUBLIC_EXPONENT, Base64.DEFAULT))
        val publicKey = KeyFactory.getInstance("RSA")
            .generatePublic(RSAPublicKeySpec(modulus, exponent))
        val verifier = Signature.getInstance("SHA256withRSA")
        verifier.initVerify(publicKey)
        verifier.update(canonical.toByteArray(Charsets.UTF_8))
        return verifier.verify(signatureBytes)
    }

    private fun canonicalLicensePayload(payload: JSONObject): String {
        return listOf(
            payload.optString("licenseId"),
            payload.optString("businessId"),
            payload.optString("stickId"),
            payload.optString("issuedAt"),
            payload.optBoolean("isLifetime", false).toString(),
            if (payload.isNull("validUntil")) "" else payload.optString("validUntil"),
        ).joinToString("|")
    }

    private fun licenseResult(status: String, message: String, path: String?): HashMap<String, Any?> {
        val data = HashMap<String, Any?>()
        data["status"] = status
        data["message"] = message
        data["path"] = path
        return data
    }

    private fun pickBackupFolder(result: MethodChannel.Result) {
        if (pendingBackupFolderResult != null) {
            result.error("BACKUP_PICK_BUSY", "A backup folder picker is already open.", null)
            return
        }

        pendingBackupFolderResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        startActivityForResult(intent, PICK_BACKUP_FOLDER_REQUEST_CODE)
    }

    private fun handleBackupFolderResult(resultCode: Int, data: Intent?) {
        val result = pendingBackupFolderResult ?: return
        pendingBackupFolderResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.error("BACKUP_PICK_CANCELLED", "No backup folder was selected.", null)
            return
        }

        try {
            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, flags)
            getSharedPreferences(BACKUP_PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_BACKUP_FOLDER_URI, uri.toString())
                .apply()
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("BACKUP_PICK_FAILED", error.message ?: error.toString(), null)
        }
    }

    private fun getBackupFolderUri(): String? {
        return getSharedPreferences(BACKUP_PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_BACKUP_FOLDER_URI, null)
    }

    private fun listBackups(result: MethodChannel.Result) {
        try {
            val folder = backupFolderDocument()
            if (folder == null) {
                result.success(emptyList<HashMap<String, Any?>>())
                return
            }
            val backups = contentResolver.query(
                android.provider.DocumentsContract.buildChildDocumentsUriUsingTree(
                    folder.treeUri,
                    android.provider.DocumentsContract.getTreeDocumentId(folder.treeUri),
                ),
                arrayOf(
                    android.provider.DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    android.provider.DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                    android.provider.DocumentsContract.Document.COLUMN_SIZE,
                ),
                null,
                null,
                null,
            )?.use { cursor ->
                val items = mutableListOf<HashMap<String, Any?>>()
                while (cursor.moveToNext()) {
                    val name = cursor.getString(1)
                    if (!name.endsWith(BACKUP_EXTENSION)) {
                        continue
                    }
                    val documentId = cursor.getString(0)
                    val item = HashMap<String, Any?>()
                    item["id"] = documentId
                    item["name"] = name
                    item["modifiedAt"] = cursor.getLong(2)
                    item["size"] = cursor.getLong(3)
                    items.add(item)
                }
                items.sortedByDescending { it["modifiedAt"] as Long }
            } ?: emptyList()
            result.success(backups)
        } catch (error: Exception) {
            result.error("BACKUP_LIST_FAILED", error.message ?: error.toString(), null)
        }
    }

    private fun createBackup(call: MethodCall, result: MethodChannel.Result) {
        val businessId = call.argument<String>("businessId").orEmpty()
        val businessName = call.argument<String>("businessName").orEmpty()
        try {
            val folder = backupFolderDocument()
                ?: throw IllegalStateException("Backup folder is not selected.")
            val dbFile = databasePath()
            if (!dbFile.isFile) {
                throw IllegalStateException("Local database was not found.")
            }
            checkpointDatabase(dbFile)
            val now = System.currentTimeMillis()
            val timestamp = backupTimestamp()
            val backupName = "fidelio_${timestamp}${BACKUP_EXTENSION}"
            val backupUri = android.provider.DocumentsContract.createDocument(
                contentResolver,
                folder.documentUri,
                "application/octet-stream",
                backupName,
            ) ?: throw IllegalStateException("Could not create backup file.")
            contentResolver.openOutputStream(backupUri, "w")?.use { output ->
                dbFile.inputStream().use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Could not write backup file.")

            val checksum = sha256(dbFile.readBytes())
            val metadataName = "$backupName.json"
            val metadataUri = android.provider.DocumentsContract.createDocument(
                contentResolver,
                folder.documentUri,
                "application/json",
                metadataName,
            ) ?: throw IllegalStateException("Could not create backup metadata.")
            val metadata = JSONObject()
                .put("backupId", "backup-$timestamp")
                .put("businessId", businessId)
                .put("businessName", businessName)
                .put("createdAt", now)
                .put("fileName", backupName)
                .put("checksum", checksum)
                .put("formatVersion", 1)
            contentResolver.openOutputStream(metadataUri, "w")?.use { output ->
                output.write(metadata.toString(2).toByteArray(Charsets.UTF_8))
            }

            val response = HashMap<String, Any?>()
            response["id"] = backupName
            response["name"] = backupName
            response["modifiedAt"] = now
            response["size"] = dbFile.length()
            response["checksum"] = checksum
            result.success(response)
        } catch (error: Exception) {
            result.error("BACKUP_CREATE_FAILED", error.message ?: error.toString(), null)
        }
    }

    private fun restoreBackup(call: MethodCall, result: MethodChannel.Result) {
        val documentId = call.argument<String>("id").orEmpty()
        try {
            val folder = backupFolderDocument()
                ?: throw IllegalStateException("Backup folder is not selected.")
            if (documentId.isBlank()) {
                throw IllegalStateException("Backup file is missing.")
            }
            val backupUri = android.provider.DocumentsContract.buildDocumentUriUsingTree(
                folder.treeUri,
                documentId,
            )
            val dbFile = databasePath()
            val safetyFile = File(dbFile.parentFile, "local_loyalty.before_restore.sqlite")
            if (dbFile.isFile) {
                checkpointDatabase(dbFile)
                dbFile.copyTo(safetyFile, overwrite = true)
            }
            dbFile.parentFile?.mkdirs()
            deleteWalFiles(dbFile)
            contentResolver.openInputStream(backupUri)?.use { input ->
                dbFile.outputStream().use { output -> input.copyTo(output) }
            } ?: throw IllegalStateException("Could not read backup file.")
            deleteWalFiles(dbFile)
            result.success(null)
        } catch (error: Exception) {
            result.error("BACKUP_RESTORE_FAILED", error.message ?: error.toString(), null)
        }
    }

    private fun pickAndRestoreBackup(result: MethodChannel.Result) {
        if (pendingRestorePickResult != null) {
            result.error("RESTORE_PICK_BUSY", "A backup picker is already open.", null)
            return
        }

        pendingRestorePickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/octet-stream", "application/x-sqlite3", "*/*"),
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivityForResult(intent, PICK_RESTORE_BACKUP_REQUEST_CODE)
    }

    private fun handleRestoreBackupResult(resultCode: Int, data: Intent?) {
        val result = pendingRestorePickResult ?: return
        pendingRestorePickResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.error("RESTORE_PICK_CANCELLED", "No backup file was selected.", null)
            return
        }

        try {
            restoreBackupFromUri(uri)
            result.success(null)
        } catch (error: Exception) {
            result.error("BACKUP_RESTORE_FAILED", error.message ?: error.toString(), null)
        }
    }

    private fun restoreBackupFromUri(backupUri: Uri) {
        val dbFile = databasePath()
        val tempFile = File(cacheDir, "pending_restore.fideliobackup")
        contentResolver.openInputStream(backupUri)?.use { input ->
            tempFile.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("Could not read backup file.")
        if (!isSqliteDatabase(tempFile)) {
            tempFile.delete()
            throw IllegalStateException("Selected file is not a Fidelio backup database.")
        }

        val safetyFile = File(dbFile.parentFile, "local_loyalty.before_restore.sqlite")
        if (dbFile.isFile) {
            checkpointDatabase(dbFile)
            dbFile.copyTo(safetyFile, overwrite = true)
        }
        dbFile.parentFile?.mkdirs()
        deleteWalFiles(dbFile)
        tempFile.copyTo(dbFile, overwrite = true)
        tempFile.delete()
        deleteWalFiles(dbFile)
    }

    private fun backupFolderDocument(): BackupFolder? {
        val uriText = getBackupFolderUri() ?: return null
        val treeUri = Uri.parse(uriText)
        val documentUri = android.provider.DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            android.provider.DocumentsContract.getTreeDocumentId(treeUri),
        )
        return BackupFolder(treeUri, documentUri)
    }

    private fun databasePath(): File {
        val dataRoot = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            applicationContext.dataDir
        } else {
            filesDir.parentFile ?: filesDir
        }
        return File(File(dataRoot, "app_flutter"), "local_loyalty.sqlite")
    }

    private fun checkpointDatabase(dbFile: File) {
        if (!dbFile.isFile) {
            return
        }
        try {
            SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            ).use { database ->
                database.rawQuery("PRAGMA wal_checkpoint(FULL)", null).use { cursor ->
                    cursor.moveToFirst()
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun deleteWalFiles(dbFile: File) {
        File("${dbFile.absolutePath}-wal").delete()
        File("${dbFile.absolutePath}-shm").delete()
    }

    private fun isSqliteDatabase(file: File): Boolean {
        if (!file.isFile || file.length() < SQLITE_HEADER.size) {
            return false
        }
        val header = ByteArray(SQLITE_HEADER.size)
        file.inputStream().use { input ->
            if (input.read(header) != SQLITE_HEADER.size) {
                return false
            }
        }
        return header.contentEquals(SQLITE_HEADER)
    }

    private fun backupTimestamp(): String {
        val formatter = java.text.SimpleDateFormat("yyyyMMdd_HHmmss", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getDefault()
        return formatter.format(java.util.Date())
    }

    private fun sha256(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString("") { "%02x".format(it) }
    }

    private data class BackupFolder(val treeUri: Uri, val documentUri: Uri)

    private data class LicenseSource(
        val content: String,
        val path: String,
        val stickId: String?,
    )

    companion object {
        private const val CHANNEL_NAME = "fidelio/nfc_access"
        private const val LICENSE_CHANNEL_NAME = "fidelio/license"
        private const val BACKUP_CHANNEL_NAME = "fidelio/backup"
        private const val LICENSE_PREFS_NAME = "fidelio_license_prefs"
        private const val KEY_LICENSE_URI = "license_uri"
        private const val PICK_LICENSE_REQUEST_CODE = 8021
        private const val BACKUP_PREFS_NAME = "fidelio_backup_prefs"
        private const val KEY_BACKUP_FOLDER_URI = "backup_folder_uri"
        private const val PICK_BACKUP_FOLDER_REQUEST_CODE = 8022
        private const val PICK_RESTORE_BACKUP_REQUEST_CODE = 8023
        private const val BACKUP_EXTENSION = ".fideliobackup"
        private val SQLITE_HEADER = byteArrayOf(
            0x53,
            0x51,
            0x4C,
            0x69,
            0x74,
            0x65,
            0x20,
            0x66,
            0x6F,
            0x72,
            0x6D,
            0x61,
            0x74,
            0x20,
            0x33,
            0x00,
        )
        private const val LICENSE_RELATIVE_PATH = "Fidelio/fidelio_license.json"
        private const val LICENSE_PUBLIC_MODULUS = "4HqTbvCeug4u77yX+7Y4uPFxrbO70kaVNdnF+ruI/OgMxbQ1Moi0iwJLayeYcC57BcDPegAde61uHjR8v72FuyWQW8asNOw2usfgbP+adHd1bucxg4uXN5TUkK9V7VdkSfcyaIqIY6HlyPpnqSnzPpe9VsFt8sxVHXgUhvYPa2YCjfqatdegK9SPKtJake3PhtofvQWOEngNc+nS9ZEmXnJ6bh7e6RnHBp/zvgsLpCRCl4R374iN/+uETUcbp4b5c2UMenp9+ITqCk9PF1Yx78zqIXGo7PGyP/CZ4RKfeGGbghDw9U4ASPRbkZFiLkB2HbWtxQ3LqayWwK1igU/bdQ=="
        private const val LICENSE_PUBLIC_EXPONENT = "AQAB"
        private const val MAX_CHUNK_SIZE = 220
        private const val MAX_PAYLOAD_SIZE = 16 * 1024
        private const val READ_TIMEOUT_MS = 20_000L
        private val SELECT_AID_COMMAND = byteArrayOf(
            0x00.toByte(),
            0xA4.toByte(),
            0x04.toByte(),
            0x00.toByte(),
            0x07.toByte(),
            0xF0.toByte(),
            0x01.toByte(),
            0x02.toByte(),
            0x03.toByte(),
            0x04.toByte(),
            0x05.toByte(),
            0x06.toByte(),
            0x00.toByte(),
        )
        private val GET_INFO_COMMAND = byteArrayOf(
            0x80.toByte(),
            0xCA.toByte(),
            0x00.toByte(),
            0x00.toByte(),
            0x00.toByte(),
        )
        private val WRITE_COMMIT_COMMAND = byteArrayOf(
            0x80.toByte(),
            0xD2.toByte(),
            0x00.toByte(),
            0x00.toByte(),
            0x00.toByte(),
        )
    }
}
