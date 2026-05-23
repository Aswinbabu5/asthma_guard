import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AsthmaGuardApp());
}

class AsthmaGuardApp extends StatelessWidget {
  const AsthmaGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AsthmaGuard AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.bg,
        fontFamily: 'Rajdhani',
        colorScheme: const ColorScheme.dark(
          primary:   AppTheme.accent,
          secondary: AppTheme.safe,
          error:     AppTheme.danger,
          surface:   AppTheme.panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.panel,
          foregroundColor: AppTheme.textBright,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: AppTheme.textBright,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.panelLight,
          labelStyle: const TextStyle(color: AppTheme.textDim),
          hintStyle: const TextStyle(color: AppTheme.textDim),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/':          (_) => const SplashScreen(),
        '/login':     (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/history':   (_) => const HistoryScreen(),
        '/settings':  (_) => const SettingsScreen(),
      },
    );
  }
}