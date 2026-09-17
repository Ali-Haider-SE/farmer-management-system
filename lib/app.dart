import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';
import 'services/settings_controller.dart';

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
            themeMode: settings.themeMode,
            theme: _lightTheme(settings.visualDensity),
            darkTheme: _darkTheme(settings.visualDensity),

            home: const _SessionGate(),

            onGenerateRoute: (routeSettings) {
              if (routeSettings.name == '/dashboard') {
                final role = routeSettings.arguments is String
                    ? routeSettings.arguments as String
                    : 'Admin';

                return MaterialPageRoute(
                  builder: (context) => DashboardPage(role: role),
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

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B5E20),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (auth.isLoggedIn && auth.currentUser != null) {
      return DashboardPage(role: auth.currentUser!.role);
    }

    return const LoginPage();
  }
}
