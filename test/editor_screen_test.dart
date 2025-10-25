// Comprehensive tests for Amber Writer editor functionality
// Tests list continuation, edit/reading modes, exports, and document management

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amber_writer/screens/editor_screen.dart';
import 'package:amber_writer/services/settings_service.dart';

void main() {
  group('List Continuation Tests', () {
    testWidgets('Should continue bullet list on Enter', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Find the text field
      final textField = find.byType(CupertinoTextField);
      expect(textField, findsOneWidget);

      // Enter bullet list item
      await tester.enterText(textField, '- First item');
      await tester.pumpAndSettle();

      // Simulate Enter key by adding newline
      await tester.enterText(textField, '- First item\n');
      await tester.pumpAndSettle();

      // Verify bullet marker was added
      final CupertinoTextField field = tester.widget(textField);
      expect(field.controller!.text, contains('- First item\n- '));
    });

    testWidgets('Should continue numbered list on Enter', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(CupertinoTextField);

      // Enter numbered list item
      await tester.enterText(textField, '1. First item');
      await tester.pumpAndSettle();

      // Simulate Enter key
      await tester.enterText(textField, '1. First item\n');
      await tester.pumpAndSettle();

      // Verify next number was added
      final CupertinoTextField field = tester.widget(textField);
      expect(field.controller!.text, contains('1. First item\n2. '));
    });

    testWidgets('Should exit list on Enter for empty bullet item', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(CupertinoTextField);

      // Enter empty bullet list item
      await tester.enterText(textField, '- ');
      await tester.pumpAndSettle();

      // Simulate Enter key
      await tester.enterText(textField, '- \n');
      await tester.pumpAndSettle();

      // Verify bullet marker was removed
      final CupertinoTextField field = tester.widget(textField);
      expect(field.controller!.text, equals('\n'));
    });

    testWidgets('Should allow deletion of list markers', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(CupertinoTextField);

      // Enter list item
      await tester.enterText(textField, '1. Item');
      await tester.pumpAndSettle();

      // Delete backwards to remove list marker
      await tester.enterText(textField, '1. ');
      await tester.pumpAndSettle();

      // Should not add marker back when deleting
      final CupertinoTextField field = tester.widget(textField);
      expect(field.controller!.text, equals('1. '));
    });
  });

  group('Edit/Reading Mode Tests', () {
    testWidgets('Should toggle between edit and reading mode', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Find the eye icon button (reading mode toggle)
      final toggleButton = find.byIcon(CupertinoIcons.eye);
      expect(toggleButton, findsOneWidget);

      // Tap to enter reading mode
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verify icon changed to pencil (edit mode icon)
      expect(find.byIcon(CupertinoIcons.pencil), findsOneWidget);

      // Tap again to return to edit mode
      await tester.tap(find.byIcon(CupertinoIcons.pencil));
      await tester.pumpAndSettle();

      // Verify icon changed back to eye
      expect(find.byIcon(CupertinoIcons.eye), findsOneWidget);
    });

    testWidgets('Reading mode should render formatted headings', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Enter markdown with heading
      final textField = find.byType(CupertinoTextField);
      await tester.enterText(textField, '# Heading\nSome text');
      await tester.pumpAndSettle();

      // Switch to reading mode
      final toggleButton = find.byIcon(CupertinoIcons.eye);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verify heading is rendered (without # marker in display)
      expect(find.text('Heading'), findsOneWidget);
    });
  });

  group('Document Management Tests', () {
    testWidgets('Should create new document', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Find the + button
      final addButton = find.byIcon(CupertinoIcons.add);
      expect(addButton, findsOneWidget);

      // Tap to create new document
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Verify new document has default date title
      // (Date format: "Mon Oct 25" or similar)
      final textField = find.byType(CupertinoTextField);
      final CupertinoTextField field = tester.widget(textField);
      expect(field.controller!.text, isNotEmpty);
    });

    testWidgets('Should toggle sidebar', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Find the sidebar toggle button
      final sidebarButton = find.byIcon(CupertinoIcons.list_bullet);
      expect(sidebarButton, findsOneWidget);

      // Tap to open sidebar
      await tester.tap(sidebarButton);
      await tester.pumpAndSettle();

      // Verify sidebar opened (shows "Documents" text)
      expect(find.text('Documents'), findsOneWidget);
    });
  });

  group('Markdown Shortcuts Tests', () {
    testWidgets('Should cycle heading levels with Cmd+H', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Enter some text
      final textField = find.byType(CupertinoTextField);
      await tester.enterText(textField, 'Heading text');
      await tester.pumpAndSettle();

      // Open actions menu
      final menuButton = find.byIcon(CupertinoIcons.ellipsis);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Find and tap "Cycle Heading Level"
      final headingOption = find.text('Cycle Heading Level');
      expect(headingOption, findsOneWidget);
      await tester.tap(headingOption);
      await tester.pumpAndSettle();

      // Verify heading marker was added
      final CupertinoTextField field = tester.widget(textField);
      expect(field.controller!.text, startsWith('#'));
    });

    testWidgets('Should toggle full width mode', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Open actions menu
      final menuButton = find.byIcon(CupertinoIcons.ellipsis);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Find and tap "Full Width Mode"
      final fullWidthOption = find.text('Full Width Mode');
      expect(fullWidthOption, findsOneWidget);
      await tester.tap(fullWidthOption);
      await tester.pumpAndSettle();

      // Open menu again to verify it changed
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Verify text changed to "Exit Full Width"
      expect(find.text('Exit Full Width'), findsOneWidget);
    });
  });

  group('Export Tests', () {
    testWidgets('Should show export options in menu', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Open actions menu
      final menuButton = find.byIcon(CupertinoIcons.ellipsis);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Verify export options exist
      expect(find.text('Export to PDF'), findsOneWidget);
      expect(find.text('Export to Markdown'), findsOneWidget);
      expect(find.text('Open in Claude Chat'), findsOneWidget);
    });
  });

  group('Settings Tests', () {
    testWidgets('Should open settings modal', (WidgetTester tester) async {
      final settingsService = SettingsService();

      await tester.pumpWidget(
        CupertinoApp(
          home: EditorScreen(settingsService: settingsService),
        ),
      );
      await tester.pumpAndSettle();

      // Find the theme/settings button
      final settingsButtons = find.byType(CupertinoButton);

      // Tap settings button (sun/moon icon)
      await tester.tap(settingsButtons.at(2)); // Third button in nav bar
      await tester.pumpAndSettle();

      // Verify settings modal opened
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
    });
  });
}
