abstract interface class CryptoService {
  Future<String> generateKeyPair();

  Future<String> sign({required String payload, required String privateKeyRef});

  Future<bool> verifySignature({
    required String payload,
    required String signature,
    required String publicKey,
  });

  Future<String> checksum(String filePath);
}
