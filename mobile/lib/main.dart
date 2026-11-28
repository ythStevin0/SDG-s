import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/petani_shell.dart';
import 'screens/role_dashboards.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpanJualApp());
}

class SimpanJualApp extends StatefulWidget {
  const SimpanJualApp({super.key});

  @override
  State<SimpanJualApp> createState() => _SimpanJualAppState();
}

class _SimpanJualAppState extends State<SimpanJualApp> {
  final AppState _appState = AppState();
  bool _showAuth = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'SimpanJual: Keputusan Pascapanen',
          debugShowCheckedModeBanner: false,
          theme: buildSimpanJualTheme(
            isDark: _appState.darkMode,
            fieldMode: _appState.fieldMode,
          ),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(_appState.fieldMode ? 1.14 : 1.0),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    final user = _appState.currentUser;
    if (user != null) {
      switch (user.role) {
        case 'gudang':
          return GudangDashboardScreen(appState: _appState);
        case 'pembeli':
          return PembeliDashboardScreen(appState: _appState);
        case 'admin':
          return AdminDashboardScreen(appState: _appState);
        default:
          return PetaniShell(appState: _appState);
      }
    }

    if (_showAuth) {
      return AuthScreen(
        appState: _appState,
        onBackToLanding: () => setState(() => _showAuth = false),
      );
    }

    return LandingScreen(
      appState: _appState,
      onOpenAuth: () => setState(() => _showAuth = true),
    );
  }
}
