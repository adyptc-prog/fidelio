import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BirthdayRewardCardScreen extends StatefulWidget {
  const BirthdayRewardCardScreen({
    required this.customerName,
    required this.businessName,
    super.key,
  });

  final String customerName;
  final String businessName;

  @override
  State<BirthdayRewardCardScreen> createState() =>
      _BirthdayRewardCardScreenState();
}

class _BirthdayRewardCardScreenState extends State<BirthdayRewardCardScreen> {
  final _boundaryKey = GlobalKey();
  bool _isSharing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Birthday Reward')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: _BirthdayCard(
                      customerName: widget.customerName,
                      businessName: widget.businessName,
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              FilledButton.icon(
                icon: const Icon(Icons.share),
                label: Text(_isSharing ? 'Preparing...' : 'Share'),
                onPressed: _isSharing ? null : _share,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/birthday_reward_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              'Happy Birthday, ${widget.customerName}! You received a '
              'birthday reward from ${widget.businessName}.',
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = 'Could not share the card: $error');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({required this.customerName, required this.businessName});

  final String customerName;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071F1C), Color(0xFF0E4A40), Color(0xFF5D4210)],
        ),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33061412),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Happy Birthday, $customerName!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Congratulations! You've received a birthday reward on your "
            '$businessName card.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Text(
            'Update your card on your next visit to $businessName.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
