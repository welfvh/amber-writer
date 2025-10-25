// Mode selection screen for choosing Controller (Mac) or Display (DC1) mode
// Shows on first launch or when mode needs to be selected

import 'package:flutter/cupertino.dart';
import '../models/app_mode.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final bgColor = isDark ? CupertinoColors.black : CupertinoColors.white;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Amber Writer',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose device mode',
                style: TextStyle(
                  fontSize: 17,
                  color: isDark
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 48),
              // Controller mode (Mac)
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    '/editor',
                    arguments: AppMode.controller,
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.device_laptop, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Controller (Mac)',
                      style: TextStyle(fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Display mode (DC1)
              CupertinoButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    '/editor',
                    arguments: AppMode.display,
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.device_phone_portrait, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Display (DC1)',
                      style: TextStyle(fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Connection instructions
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : CupertinoColors.secondarySystemBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.info_circle,
                          size: 20,
                          color: CupertinoColors.activeBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'USB Connection Setup',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Connect DC1 to Mac via USB\n'
                      '2. On Mac, run:\n'
                      '   adb reverse tcp:8080 tcp:8080\n'
                      '3. Launch Controller mode on Mac\n'
                      '4. Launch Display mode on DC1',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.secondaryLabel,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
