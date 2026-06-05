import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/app_settings_providers.dart';
import 'providers/business_profile_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import '../domain/entities/app_settings.dart';
import '../domain/value_objects/app_mode.dart';

class LocalLoyaltyApp extends ConsumerWidget {
  const LocalLoyaltyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);

    return settings.when(
      data: (settings) {
        if (settings.selectedMode == AppMode.business) {
          final businessProfile = ref.watch(businessProfileControllerProvider);
          return businessProfile.when(
            data: (profile) => _RouterApp(
              settings: settings,
              hasBusinessProfile: profile != null,
            ),
            loading: () => const _LoadingApp(),
            error: (error, stackTrace) =>
                _SettingsErrorApp(message: error.toString()),
          );
        }

        return _RouterApp(settings: settings, hasBusinessProfile: false);
      },
      loading: () => MaterialApp(
        title: 'Fidelio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const _LoadingScreen(),
      ),
      error: (error, stackTrace) => MaterialApp(
        title: 'Fidelio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: _SettingsErrorScreen(message: error.toString()),
      ),
    );
  }
}

class _RouterApp extends StatefulWidget {
  const _RouterApp({required this.settings, required this.hasBusinessProfile});

  final AppSettings settings;
  final bool hasBusinessProfile;

  @override
  State<_RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends State<_RouterApp> {
  late GoRouter _router;
  late AppMode? _selectedMode;
  late bool _hasBusinessProfile;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.settings.selectedMode;
    _hasBusinessProfile = widget.hasBusinessProfile;
    _router = _createRouter();
  }

  @override
  void didUpdateWidget(covariant _RouterApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routingChanged =
        widget.settings.selectedMode != _selectedMode ||
        widget.hasBusinessProfile != _hasBusinessProfile;

    if (!routingChanged) {
      return;
    }

    _selectedMode = widget.settings.selectedMode;
    _hasBusinessProfile = widget.hasBusinessProfile;
    _router.dispose();
    _router = _createRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  GoRouter _createRouter() {
    return createAppRouter(
      selectedMode: _selectedMode,
      hasBusinessProfile: _hasBusinessProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fidelio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => _ScaledApp(
        zoomMode: widget.settings.zoomMode,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: _router,
    );
  }
}

class _LoadingApp extends StatelessWidget {
  const _LoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fidelio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _LoadingScreen(),
    );
  }
}

class _SettingsErrorApp extends StatelessWidget {
  const _SettingsErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fidelio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: _SettingsErrorScreen(message: message),
    );
  }
}

class _ScaledApp extends StatelessWidget {
  const _ScaledApp({required this.zoomMode, required this.child});

  final AppZoomMode zoomMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final multiplier = zoomMode == AppZoomMode.large ? 1.16 : 1.0;

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: multiplier,
          maxScaleFactor: multiplier,
        ),
      ),
      child: child,
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SettingsErrorScreen extends StatelessWidget {
  const _SettingsErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load local settings: $message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
