import 'package:flutter/material.dart';

const licenseRequiredSupportEmail = 'voltacademy007@gmail.com';

Future<void> showLicenseRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('License required'),
      content: const Text(
        'You have reached the limit of 10 free memberships/loyalty cards. '
        'To create more, you need a license. Contact support at '
        '$licenseRequiredSupportEmail.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
