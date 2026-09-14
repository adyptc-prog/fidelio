import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelio/app/providers/business_check_in_providers.dart';
import 'package:fidelio/app/providers/scan_feedback_providers.dart';

void main() {
  group('categorizeCheckInResult', () {
    test('valid results map to visitValid', () {
      expect(
        categorizeCheckInResult(
          const CheckInScanResult(
            isValid: true,
            message: 'Validated successfully',
          ),
        ),
        ScanFeedbackEvent.visitValid,
      );
      expect(
        categorizeCheckInResult(
          const CheckInScanResult(isValid: true, message: 'threshold_reached'),
        ),
        ScanFeedbackEvent.visitValid,
      );
      expect(
        categorizeCheckInResult(
          const CheckInScanResult(isValid: true, message: 'bonus_entry'),
        ),
        ScanFeedbackEvent.visitValid,
      );
    });

    test('expired and not-yet-active map to cardExpired', () {
      expect(
        categorizeCheckInResult(
          const CheckInScanResult(isValid: false, message: 'expired'),
        ),
        ScanFeedbackEvent.cardExpired,
      );
      expect(
        categorizeCheckInResult(
          const CheckInScanResult(isValid: false, message: 'not_active_yet'),
        ),
        ScanFeedbackEvent.cardExpired,
      );
    });

    test('invalid or unknown QR codes map to codeNotAccepted', () {
      expect(
        categorizeCheckInResult(
          const CheckInScanResult(isValid: false, message: 'invalid QR'),
        ),
        ScanFeedbackEvent.codeNotAccepted,
      );
      expect(
        categorizeCheckInResult(
          const CheckInScanResult(isValid: false, message: 'unknown'),
        ),
        ScanFeedbackEvent.codeNotAccepted,
      );
    });

    test('other business-rule rejections map to visitRejected', () {
      for (final message in [
        'reused QR',
        'wallet mismatch',
        'no entries',
        'suspended',
        'card_completed',
      ]) {
        expect(
          categorizeCheckInResult(
            CheckInScanResult(isValid: false, message: message),
          ),
          ScanFeedbackEvent.visitRejected,
          reason: 'message: $message',
        );
      }
    });
  });

  testWidgets(
    'ScanFeedbackController.play never throws through the widget tree without audio/vibration platforms',
    (tester) async {
      Object? caught;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              return MaterialApp(
                home: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(scanFeedbackControllerProvider)
                          .play(ScanFeedbackEvent.scanDetected);
                    } on Object catch (error) {
                      caught = error;
                    }
                  },
                  child: const Text('play'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(caught, isNull);
    },
  );
}
