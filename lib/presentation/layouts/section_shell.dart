import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SectionShell extends StatelessWidget {
  const SectionShell({
    required this.title,
    required this.child,
    this.showBackButton = true,
    this.actions,
    super.key,
  });

  final String title;
  final Widget child;
  final bool showBackButton;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go('/');
                },
              )
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF07110F),
                    Color(0xFF0D1E1A),
                    Color(0xFF120F08),
                  ]
                : const [
                    Color(0xFFF4F0E7),
                    Color(0xFFEAF2EE),
                    Color(0xFFF9F7F1),
                  ],
            stops: const [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}
