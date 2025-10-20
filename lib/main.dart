// Main entry point for Amber Writer - A minimalist markdown text editor
// optimized for Daylight Computer with elegant typography using Times New Roman.
// Uses iOS-style Cupertino widgets for clean, distraction-free writing.

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'screens/editor_screen.dart';

void main() {
  // Lock to portrait mode for optimal reading experience
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AmberWriterApp());
}

class AmberWriterApp extends StatelessWidget {
  const AmberWriterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Amber Writer',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.black,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: 'Times New Roman',
            fontSize: 18,
            height: 1.6,
            color: CupertinoColors.black,
          ),
        ),
      ),
      home: const EditorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
