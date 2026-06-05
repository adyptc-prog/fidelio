import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/services/nfc_access_service.dart';

class AndroidNfcAccessService implements NfcAccessService {
  const AndroidNfcAccessService();

  static const _channel = MethodChannel('fidelio/nfc_access');

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final available = await _channel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String> readPayload() async {
    if (!Platform.isAndroid) {
      throw const NfcAccessException(
        'Direct phone-to-phone NFC is available only on Android.',
      );
    }
    try {
      final payload = await _channel.invokeMethod<String>('readPayload');
      if (payload == null || payload.trim().isEmpty) {
        throw const NfcAccessException('No NFC payload was received.');
      }
      return payload;
    } on NfcAccessException {
      rethrow;
    } on PlatformException catch (e) {
      throw NfcAccessException(e.message ?? 'NFC communication failed.');
    }
  }

  @override
  Future<void> writePayload(String rawPayload) async {
    if (!Platform.isAndroid) {
      throw const NfcAccessException(
        'Direct phone-to-phone NFC is available only on Android.',
      );
    }
    try {
      await _channel.invokeMethod<void>('sharePayload', rawPayload);
    } on PlatformException catch (e) {
      throw NfcAccessException(e.message ?? 'NFC write failed.');
    }
  }

  @override
  Future<void> sendPayload(String rawPayload) async {
    if (!Platform.isAndroid) {
      throw const NfcAccessException(
        'Direct phone-to-phone NFC is available only on Android.',
      );
    }
    try {
      await _channel.invokeMethod<void>('sendPayload', rawPayload);
    } on PlatformException catch (e) {
      throw NfcAccessException(e.message ?? 'NFC send failed.');
    }
  }

  @override
  Future<String> receivePayload() async {
    if (!Platform.isAndroid) {
      throw const NfcAccessException(
        'Direct phone-to-phone NFC is available only on Android.',
      );
    }
    try {
      final payload = await _channel.invokeMethod<String>('receivePayload');
      if (payload == null || payload.trim().isEmpty) {
        throw const NfcAccessException('No NFC payload was received.');
      }
      return payload;
    } on NfcAccessException {
      rethrow;
    } on PlatformException catch (e) {
      throw NfcAccessException(e.message ?? 'NFC communication failed.');
    }
  }
}

class NfcAccessException implements Exception {
  const NfcAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}
