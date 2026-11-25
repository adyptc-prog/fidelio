import 'package:flutter/material.dart';
import 'package:fidelio/app/localization/app_language.dart';

const licenseRequiredSupportEmail = 'voltacademy007@gmail.com';

Future<void> showLicenseRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t('License required')),
      content: Text(
        tr('Ai atins limita de 10 abonamente/carduri de fidelitate gratuite. '
            'Ca să creezi mai multe, ai nevoie de o licență. Contactează-ne la '
            '$licenseRequiredSupportEmail.',
            'You have reached the limit of 10 free memberships/loyalty cards. '
            'To create more, you need a license. Contact support at '
            '$licenseRequiredSupportEmail.'),
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
