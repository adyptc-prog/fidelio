import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_check_in_providers.dart';

/// The distinct sound + vibration cues played around a QR/NFC scan.
enum ScanFeedbackEvent {
  /// Played the moment a QR code is detected by the camera, both for
  /// business access scans and for client card imports.
  scanDetected,

  /// Played when a check-in / access scan is accepted.
  visitValid,

  /// Played when a scan is rejected by a business rule (suspended, no
  /// entries left, already used, wrong wallet, fully used card, ...).
  visitRejected,

  /// Played when the card exists but is outside its validity period
  /// (expired, or not active yet).
  cardExpired,

  /// Played when the scanned code itself is not recognized or not valid.
  codeNotAccepted,
}

final scanFeedbackControllerProvider = Provider<ScanFeedbackController>((ref) {
  final controller = ScanFeedbackController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Plays short local sound + vibration cues for scan feedback, in both
/// business and client mode. Feedback is a best-effort UX enhancement, so
/// playback/vibration errors (missing platform support, muted device,
/// running under `flutter test`, ...) are swallowed rather than surfaced.
class ScanFeedbackController {
  ScanFeedbackController({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  static const _assetPaths = {
    ScanFeedbackEvent.scanDetected: 'sounds/scan_beep.wav',
    ScanFeedbackEvent.visitValid: 'sounds/visit_valid.wav',
    ScanFeedbackEvent.visitRejected: 'sounds/visit_rejected.wav',
    ScanFeedbackEvent.cardExpired: 'sounds/card_expired.wav',
    ScanFeedbackEvent.codeNotAccepted: 'sounds/code_not_accepted.wav',
  };

  Future<void> play(ScanFeedbackEvent event) async {
    await Future.wait([_playSound(event), _vibrate(event)]);
  }

  Future<void> _playSound(ScanFeedbackEvent event) async {
    final assetPath = _assetPaths[event];
    if (assetPath == null) {
      return;
    }
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } on Object {
      // Ignore playback failures; sound is a UX cue, not app logic.
    }
  }

  // Uses Flutter's built-in HapticFeedback (System UI feedback) instead of
  // the `vibration` plugin's pattern API: that plugin tags Android
  // vibrations with AudioAttributes.USAGE_ALARM, which many devices
  // silently suppress whenever the alarm volume/vibration is off. Built-in
  // haptics go through the standard touch-feedback channel instead, which
  // is reliably felt regardless of alarm settings.
  Future<void> _vibrate(ScanFeedbackEvent event) async {
    try {
      switch (event) {
        case ScanFeedbackEvent.scanDetected:
          await HapticFeedback.selectionClick();
        case ScanFeedbackEvent.visitValid:
          await HapticFeedback.lightImpact();
          await Future.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.lightImpact();
        case ScanFeedbackEvent.visitRejected:
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.mediumImpact();
        case ScanFeedbackEvent.cardExpired:
          await HapticFeedback.heavyImpact();
        case ScanFeedbackEvent.codeNotAccepted:
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.heavyImpact();
      }
    } on Object {
      // Ignore haptics failures (e.g. platforms without vibration support).
    }
  }

  /// Plays the outcome feedback matching a check-in scan result.
  Future<void> playForCheckInResult(CheckInScanResult result) {
    return play(categorizeCheckInResult(result));
  }

  Future<void> dispose() => _player.dispose();
}

/// Maps a [CheckInScanResult] to the feedback category that should play.
ScanFeedbackEvent categorizeCheckInResult(CheckInScanResult result) {
  if (result.isValid) {
    return ScanFeedbackEvent.visitValid;
  }
  return switch (result.message) {
    'expired' || 'not_active_yet' => ScanFeedbackEvent.cardExpired,
    'invalid QR' ||
    'unknown' ||
    'not_a_referral' => ScanFeedbackEvent.codeNotAccepted,
    _ => ScanFeedbackEvent.visitRejected,
  };
}
