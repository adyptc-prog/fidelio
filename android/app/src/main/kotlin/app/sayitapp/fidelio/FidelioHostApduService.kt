package app.sayitapp.fidelio

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.content.Intent
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class FidelioHostApduService : HostApduService() {
    private var selected = false
    private var incomingPayloadLength = 0
    private var incomingPayload = ByteArrayOutputStream()

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val command = commandApdu ?: return STATUS_FAILED
        return when {
            isSelectAidCommand(command) -> {
                selected = true
                STATUS_OK
            }
            !selected -> STATUS_CONDITIONS_NOT_SATISFIED
            isReceiveMode() && isWriteInitCommand(command) -> startIncomingPayload(command)
            isReceiveMode() && isWriteChunkCommand(command) -> appendIncomingPayload(command)
            isReceiveMode() && isWriteCommitCommand(command) -> commitIncomingPayload()
            isInfoCommand(command) -> payloadLengthResponse()
            isReadCommand(command) -> payloadChunkResponse(command)
            else -> STATUS_FAILED
        }
    }

    override fun onDeactivated(reason: Int) {
        selected = false
        incomingPayloadLength = 0
        incomingPayload = ByteArrayOutputStream()
    }

    private fun payloadLengthResponse(): ByteArray {
        val payload = payloadBytes()
        val length = ByteBuffer.allocate(4).putInt(payload.size).array()
        return length + STATUS_OK
    }

    private fun payloadChunkResponse(command: ByteArray): ByteArray {
        val payload = payloadBytes()
        val offset = ((command[2].toInt() and 0xff) shl 8) or
            (command[3].toInt() and 0xff)
        if (offset < 0 || offset > payload.size) {
            return STATUS_FAILED
        }
        val requestedLength = if (command.size >= 5) {
            command[4].toInt() and 0xff
        } else {
            MAX_CHUNK_SIZE
        }
        val chunkLength = minOf(requestedLength, MAX_CHUNK_SIZE, payload.size - offset)
        val chunk = payload.copyOfRange(offset, offset + chunkLength)
        return chunk + STATUS_OK
    }

    private fun payloadBytes(): ByteArray {
        return FidelioNfcPayloadStore.getPayload(applicationContext).toByteArray(Charsets.UTF_8)
    }

    private fun isInfoCommand(command: ByteArray): Boolean {
        return command.size >= 5 &&
            command[0] == 0x80.toByte() &&
            command[1] == 0xCA.toByte()
    }

    private fun isReadCommand(command: ByteArray): Boolean {
        return command.size >= 5 &&
            command[0] == 0x80.toByte() &&
            command[1] == 0xB0.toByte()
    }

    private fun isWriteInitCommand(command: ByteArray): Boolean {
        return command.size >= 9 &&
            command[0] == 0x80.toByte() &&
            command[1] == 0xD0.toByte()
    }

    private fun isWriteChunkCommand(command: ByteArray): Boolean {
        return command.size >= 5 &&
            command[0] == 0x80.toByte() &&
            command[1] == 0xD1.toByte()
    }

    private fun isWriteCommitCommand(command: ByteArray): Boolean {
        return command.size >= 5 &&
            command[0] == 0x80.toByte() &&
            command[1] == 0xD2.toByte()
    }

    private fun isReceiveMode(): Boolean {
        return FidelioNfcPayloadStore.isReceiveMode(applicationContext)
    }

    private fun startIncomingPayload(command: ByteArray): ByteArray {
        incomingPayloadLength = ByteBuffer.wrap(command.copyOfRange(5, 9)).int
        if (incomingPayloadLength <= 0 || incomingPayloadLength > MAX_PAYLOAD_SIZE) {
            incomingPayloadLength = 0
            return STATUS_FAILED
        }
        incomingPayload = ByteArrayOutputStream(incomingPayloadLength)
        return STATUS_OK
    }

    private fun appendIncomingPayload(command: ByteArray): ByteArray {
        if (incomingPayloadLength <= 0) {
            return STATUS_CONDITIONS_NOT_SATISFIED
        }
        val dataLength = command[4].toInt() and 0xff
        if (dataLength <= 0 || command.size < 5 + dataLength) {
            return STATUS_FAILED
        }
        val data = command.copyOfRange(5, 5 + dataLength)
        if (incomingPayload.size() + data.size > incomingPayloadLength) {
            return STATUS_FAILED
        }
        incomingPayload.write(data)
        return STATUS_OK
    }

    private fun commitIncomingPayload(): ByteArray {
        if (incomingPayloadLength <= 0 || incomingPayload.size() != incomingPayloadLength) {
            return STATUS_FAILED
        }
        val payload = incomingPayload.toByteArray().toString(Charsets.UTF_8)
        FidelioNfcPayloadStore.completeReceive(applicationContext, payload)
        sendBroadcast(Intent(ACTION_PAYLOAD_RECEIVED).setPackage(packageName))
        return STATUS_OK
    }

    private fun isSelectAidCommand(command: ByteArray): Boolean {
        if (command.size < 12 ||
            command[0] != 0x00.toByte() ||
            command[1] != 0xA4.toByte() ||
            command[2] != 0x04.toByte() ||
            command[3] != 0x00.toByte()
        ) {
            return false
        }

        val aidLength = command[4].toInt() and 0xff
        if (aidLength != FIDELIO_AID.size || command.size < 5 + aidLength) {
            return false
        }
        val aid = command.copyOfRange(5, 5 + aidLength)
        return aid.contentEquals(FIDELIO_AID)
    }

    companion object {
        private const val MAX_CHUNK_SIZE = 220
        private const val MAX_PAYLOAD_SIZE = 16 * 1024
        const val ACTION_PAYLOAD_RECEIVED = "app.sayitapp.fidelio.NFC_PAYLOAD_RECEIVED"
        private val STATUS_OK = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val STATUS_FAILED = byteArrayOf(0x6F.toByte(), 0x00.toByte())
        private val STATUS_CONDITIONS_NOT_SATISFIED = byteArrayOf(0x69.toByte(), 0x85.toByte())
        private val FIDELIO_AID = byteArrayOf(
            0xF0.toByte(),
            0x01.toByte(),
            0x02.toByte(),
            0x03.toByte(),
            0x04.toByte(),
            0x05.toByte(),
            0x06.toByte(),
        )
    }
}
