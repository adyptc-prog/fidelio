import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/usb_backup_entry.dart';

class AndroidUsbBackupService {
  const AndroidUsbBackupService();

  static const _channel = MethodChannel('fidelio/backup');

  Future<String?> getBackupFolder() async {
    if (!Platform.isAndroid) {
      return null;
    }
    return _channel.invokeMethod<String>('getBackupFolder');
  }

  Future<void> pickBackupFolder() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<String>('pickBackupFolder');
  }

  Future<List<UsbBackupEntry>> listBackups() async {
    if (!Platform.isAndroid) {
      return const [];
    }
    final result = await _channel.invokeMethod<List<Object?>>('listBackups');
    return (result ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(UsbBackupEntry.fromJson)
        .toList();
  }

  Future<UsbBackupEntry> createBackup({
    required String businessId,
    required String businessName,
  }) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'createBackup',
      {'businessId': businessId, 'businessName': businessName},
    );
    if (result == null) {
      throw const FormatException('Backup response was empty.');
    }
    return UsbBackupEntry.fromJson(result);
  }

  Future<void> restoreBackup(UsbBackupEntry backup) {
    return _channel.invokeMethod<void>('restoreBackup', {'id': backup.id});
  }

  Future<void> pickAndRestoreBackup() {
    if (!Platform.isAndroid) {
      return Future.value();
    }
    return _channel.invokeMethod<void>('pickAndRestoreBackup');
  }
}
