// Main entry point for Amber Writer - A minimalist markdown text editor
// optimized for Daylight Computer with elegant typography using Times New Roman.
// Uses iOS-style Cupertino widgets for clean, distraction-free writing.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'screens/editor_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'services/settings_service.dart';
import 'models/app_mode.dart';

void main() {
  // Allow all orientations (portrait and landscape)
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const AmberWriterApp());
}

class AmberWriterApp extends StatefulWidget {
  const AmberWriterApp({super.key});

  @override
  State<AmberWriterApp> createState() => _AmberWriterAppState();
}

class _AmberWriterAppState extends State<AmberWriterApp> {
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _settingsService.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Get system brightness from MediaQuery
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveBrightness = _settingsService.getEffectiveBrightness(systemBrightness);
    final isDark = effectiveBrightness == Brightness.dark;

    // Auto-detect mode: macOS = Controller, Android = Display
    final appMode = Platform.isMacOS ? AppMode.controller : AppMode.display;

    return CupertinoApp(
      title: 'Amber Writer',
      theme: CupertinoThemeData(
        brightness: effectiveBrightness,
        primaryColor: isDark ? CupertinoColors.white : CupertinoColors.black,
        scaffoldBackgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
        barBackgroundColor: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 18,
            height: 1.6,
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
          ),
        ),
      ),
      home: EditorScreen(
        settingsService: _settingsService,
        appMode: appMode,
      ),
      routes: {
        '/mode-selection': (context) => const ModeSelectionScreen(),
        '/editor': (context) {
          final mode = ModalRoute.of(context)!.settings.arguments as AppMode;
          return EditorScreen(
            settingsService: _settingsService,
            appMode: mode,
          );
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
