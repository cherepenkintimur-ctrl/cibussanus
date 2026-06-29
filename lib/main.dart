import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database/db_service.dart';
import 'screens/home_screen.dart';
import 'services/theme_notifier.dart';

final themeNotifier = ThemeNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DbService.instance.init();

  runApp(const RestaurantApp());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'CibusSanus',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B2030),
              brightness: Brightness.light,
              primary: const Color(0xFF6B1520),
              secondary: const Color(0xFFC9A96E),
              tertiary: const Color(0xFFD4A574),
              surface: const Color(0xFFFAF5EF),
              onSurface: const Color(0xFF1A0A0A),
            ),
            scaffoldBackgroundColor: const Color(0xFFFAF5EF),
            fontFamily: 'Georgia',
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              scrolledUnderElevation: 2,
              backgroundColor: Color(0xFF6B1520),
              foregroundColor: Color(0xFFF5E6D0),
              titleTextStyle: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF5E6D0),
              ),
            ),
            drawerTheme: const DrawerThemeData(
              backgroundColor: Color(0xFFFAF5EF),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B1520),
                foregroundColor: const Color(0xFFF5E6D0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              elevation: 4,
              backgroundColor: Color(0xFFC9A96E),
              foregroundColor: Color(0xFF1A0A0A),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFFD4B896),
              thickness: 1,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B2030),
              brightness: Brightness.dark,
              primary: const Color(0xFFC9A96E),
              secondary: const Color(0xFFA0714A),
              tertiary: const Color(0xFFD4A574),
              surface: const Color(0xFF1A0A0A),
              onSurface: const Color(0xFFF5E6D0),
            ),
            scaffoldBackgroundColor: const Color(0xFF1A0A0A),
            fontFamily: 'Georgia',
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              scrolledUnderElevation: 2,
              backgroundColor: Color(0xFF231013),
              foregroundColor: Color(0xFFF5E6D0),
              titleTextStyle: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF5E6D0),
              ),
            ),
            drawerTheme: const DrawerThemeData(
              backgroundColor: Color(0xFF1A0A0A),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: const Color(0xFF2D1518),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: const Color(0xFF2D1518),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A96E),
                foregroundColor: const Color(0xFF1A0A0A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              elevation: 4,
              backgroundColor: Color(0xFFC9A96E),
              foregroundColor: Color(0xFF1A0A0A),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFF3D1A1E),
              thickness: 1,
            ),
          ),
          themeMode: themeNotifier.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
