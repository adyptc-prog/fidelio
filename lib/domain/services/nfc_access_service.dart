abstract interface class NfcAccessService {
  Future<bool> isAvailable();

  Future<String> readPayload();

  Future<void> writePayload(String rawPayload);

  Future<void> sendPayload(String rawPayload);

  Future<String> receivePayload();
}
