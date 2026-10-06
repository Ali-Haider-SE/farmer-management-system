import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';
import 'services/settings_controller.dart';
import 'core/localization/app_localizations.dart';

class FarmerManagementApp extends StatelessWidget {
  const FarmerManagementApp({super.key});

  static const _seed = Color(0xFF1B5E20);

  ThemeData _lightTheme(VisualDensity density) {
    return ThemeData(
      primaryColor: _seed,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
      visualDensity: density,
    );
  }

  ThemeData _darkTheme(VisualDensity density) {
    return ThemeData(
      primaryColor: _seed,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      visualDensity: density,
      brightness: Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..initialize(),
      child: AnimatedBuilder(
        animation: SettingsController.instance,
        builder: (context, _) {
          final settings = SettingsController.instance;

          return MaterialApp(
            title: settings.businessName,
            debugShowCheckedModeBanner: false,
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: settings.themeMode,
            theme: _lightTheme(settings.visualDensity),
            darkTheme: _darkTheme(settings.visualDensity),

            home: const _SessionGate(),

            onGenerateRoute: (routeSettings) {
              if (routeSettings.name == '/dashboard') {
                return MaterialPageRoute(
                  builder: (context) {
                    final auth = context.watch<AuthProvider>();
                    if (auth.isLoggedIn && auth.currentUser != null) {
                      final role = routeSettings.arguments is String
                          ? routeSettings.arguments as String
                          : auth.currentUser!.role;
                      return DashboardPage(role: role);
                    }
                    return const LoginPage();
                  },
                  settings: routeSettings,
                );
              }

              return null;
            },

            onUnknownRoute: (routeSettings) {
              return MaterialPageRoute(builder: (context) => const LoginPage());
            },
          );
        },
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B5E20),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (auth.isServerUnreachable) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Server Unreachable',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  auth.error ?? 'Could not connect to the server.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => auth.initialize(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => auth.clearError(),
                  child: const Text('Proceed to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (auth.isLoggedIn && auth.currentUser != null) {
      return DashboardPage(role: auth.currentUser!.role);
    }

    return const LoginPage();
  }
}
