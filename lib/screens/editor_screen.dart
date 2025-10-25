// Main editor screen - Minimalist markdown text editor with iOS-style UI
// Features: Full-width mode, PDF export, Claude chat integration, keyboard shortcuts

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../services/settings_service.dart';
import '../services/markdown_text_controller.dart';

// Intent classes for keyboard shortcuts
class BoldIntent extends Intent {
  const BoldIntent();
}

class ItalicIntent extends Intent {
  const ItalicIntent();
}

class HeadingIntent extends Intent {
  const HeadingIntent();
}

class EditorScreen extends StatefulWidget {
  final SettingsService settingsService;

  const EditorScreen({super.key, required this.settingsService});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  final MarkdownTextEditingController _controller = MarkdownTextEditingController();
  final StorageService _storageService = StorageService();
  final PdfService _pdfService = PdfService();
  final FocusNode _focusNode = FocusNode();

  Document? _currentDocument;
  List<Document> _allDocuments = [];
  bool _isFullWidth = false;
  bool _showPreview = false;
  bool _showUI = true;
  bool _showSidebar = false;
  double _lastScrollOffset = 0.0;
  bool _isHandlingListContinuation = false;
  int _lastTextLength = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDocument();
    _loadAllDocuments();
    // Don't apply saved brightness on startup - submit to system brightness instead
    _enableImmersiveMode();
    _syncBrightnessFromSystem();

    // Auto-save on text change, hide UI when typing, and detect markdown shortcuts
    _controller.addListener(() {
      _autoSave();
      _detectMarkdownShortcuts();
      _handleListContinuation();
      // Hide UI when typing
      if (_showUI) {
        setState(() {
          _showUI = false;
        });
      }
    });

    // Listen for focus changes
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showUI) {
        // When focusing, start with UI visible
        setState(() {
          _showUI = true;
        });
      }
    });
  }

  // Sync brightness from system when returning to app
  void _syncBrightnessFromSystem() async {
    try {
      final systemBrightness = await ScreenBrightness().current;
      // Only update if significantly different to avoid conflicts
      if ((systemBrightness - widget.settingsService.brightness).abs() > 0.001) {
        await widget.settingsService.setBrightness(systemBrightness);
        setState(() {});
      }
    } catch (e) {
      // Brightness reading might not be available on all platforms
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Sync brightness when returning to app
      _syncBrightnessFromSystem();
      _enableImmersiveMode(); // Re-enable immersive mode after returning
    }
  }

  // Enable immersive mode on Android to hide system bars
  void _enableImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  // Apply saved brightness setting
  Future<void> _applyBrightness() async {
    try {
      await ScreenBrightness().setScreenBrightness(widget.settingsService.brightness);
    } catch (e) {
      // Brightness control might not be available on all platforms
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Load last document or create new one
  Future<void> _loadDocument() async {
    final doc = await _storageService.loadCurrentDocument();

    if (doc != null) {
      setState(() {
        _currentDocument = doc;
        _controller.text = doc.content;
      });
    } else {
      // Create new document
      _currentDocument = Document(
        id: const Uuid().v4(),
        content: '',
        lastModified: DateTime.now(),
      );
    }
  }

  // Load all documents for sidebar
  Future<void> _loadAllDocuments() async {
    final docs = await _storageService.loadAllDocuments();
    setState(() {
      _allDocuments = docs;
    });
  }

  // Create new document with date as default title (e.g., "Mon Oct 29")
  Future<void> _createNewDocument() async {
    // Save current document first
    if (_currentDocument != null) {
      await _storageService.saveDocument(_currentDocument!);
      await _storageService.saveCurrentDocument(_currentDocument!);
    }

    // Generate default title with current date
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final defaultTitle = '${weekdays[now.weekday - 1]} ${months[now.month - 1]} ${now.day}';

    // Create new document with date as initial content
    final newDoc = Document(
      id: const Uuid().v4(),
      content: defaultTitle,
      lastModified: DateTime.now(),
    );

    setState(() {
      _currentDocument = newDoc;
      _controller.text = defaultTitle;
    });

    await _storageService.saveCurrentDocument(newDoc);
    await _loadAllDocuments();
  }

  // Switch to a different document
  Future<void> _switchToDocument(Document doc) async {
    // Save current document first
    if (_currentDocument != null) {
      await _storageService.saveDocument(_currentDocument!);
      await _storageService.saveCurrentDocument(_currentDocument!);
    }

    setState(() {
      _currentDocument = doc;
      _controller.text = doc.content;
      _showSidebar = false; // Close sidebar after switching
    });

    await _storageService.saveCurrentDocument(doc);
  }

  // Auto-save document
  Future<void> _autoSave() async {
    if (_currentDocument == null) return;

    final updatedDoc = _currentDocument!.copyWith(
      content: _controller.text,
      lastModified: DateTime.now(),
    );

    await _storageService.saveCurrentDocument(updatedDoc);
    await _storageService.saveDocument(updatedDoc);
    setState(() {
      _currentDocument = updatedDoc;
    });

    // Reload document list to update titles
    await _loadAllDocuments();
  }

  // Toggle full-width mode
  void _toggleFullWidth() {
    setState(() {
      _isFullWidth = !_isFullWidth;
    });
  }

  // Export to PDF with option to show in Finder
  Future<void> _exportToPdf() async {
    if (_currentDocument == null) return;

    try {
      final filePath = await _pdfService.exportToPdf(
        _currentDocument!.content,
        _currentDocument!.title,
      );

      if (filePath != null) {
        _showExportSuccessDialog(filePath);
      }
    } catch (e) {
      _showMessage('Failed to export PDF: $e');
    }
  }

  // Export to Markdown file with option to show in Finder
  Future<void> _exportToMarkdown() async {
    if (_currentDocument == null) return;

    try {
      final fileName = '${_currentDocument!.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.md';

      // Show save file dialog - defaults to Downloads folder
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Markdown',
        fileName: fileName,
        initialDirectory: Platform.isMacOS
            ? '${Platform.environment['HOME']}/Downloads'
            : null,
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsString(_currentDocument!.content);
        _showExportSuccessDialog(outputPath);
      }
    } catch (e) {
      _showMessage('Failed to export Markdown: $e');
    }
  }

  // Show export success dialog with option to show in Finder
  void _showExportSuccessDialog(String filePath) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: const Text('File exported successfully'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
          if (Platform.isMacOS)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.pop(context);
                // Show file in Finder on macOS
                await Process.run('open', ['-R', filePath]);
              },
              child: const Text('Show in Finder'),
            ),
        ],
      ),
    );
  }

  // Open Claude chat with document using deep link format
  Future<void> _openClaudeChat() async {
    if (_currentDocument == null || _currentDocument!.content.isEmpty) {
      _showMessage('Document is empty');
      return;
    }

    // Encode content for URL using deep link format
    final encodedContent = Uri.encodeComponent(_currentDocument!.content);

    // Use Claude's deep link format to prefill the text
    final uri = Uri.parse('https://claude.ai/new?q=$encodedContent');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Could not open Claude.ai');
    }
  }

  // Show message using Cupertino dialog
  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Cycle through heading levels
  void _insertHeading() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (selection.start == -1) return;

    // Find start of current line
    var lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Find end of current line
    var lineEnd = selection.start;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    // Get current line content
    final lineContent = text.substring(lineStart, lineEnd);

    // Count existing # markers
    int hashCount = 0;
    for (var i = 0; i < lineContent.length && lineContent[i] == '#'; i++) {
      hashCount++;
    }

    // Get line content without heading markers
    String contentWithoutHeading = lineContent;
    if (hashCount > 0) {
      contentWithoutHeading = lineContent.substring(hashCount).trimLeft();
    }

    // Cycle through heading levels: none → # → ## → ### → none
    String newLine;
    int cursorOffset;
    if (hashCount == 0) {
      newLine = '# $contentWithoutHeading';
      cursorOffset = 2; // "# "
    } else if (hashCount == 1) {
      newLine = '## $contentWithoutHeading';
      cursorOffset = 3; // "## "
    } else if (hashCount == 2) {
      newLine = '### $contentWithoutHeading';
      cursorOffset = 4; // "### "
    } else {
      newLine = contentWithoutHeading;
      cursorOffset = 0;
    }

    final newText = text.substring(0, lineStart) + newLine + text.substring(lineEnd);

    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: lineStart + cursorOffset + (selection.start - lineStart - hashCount - (hashCount > 0 ? 1 : 0)),
    );
  }

  // Wrap selection with markdown bold syntax
  void _toggleBold() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final text = _controller.text;
    final selectedText = selection.textInside(text);

    // Check if already bold
    final before = selection.start >= 2 ? text.substring(selection.start - 2, selection.start) : '';
    final after = selection.end + 2 <= text.length ? text.substring(selection.end, selection.end + 2) : '';

    if (before == '**' && after == '**') {
      // Remove bold
      final newText = text.substring(0, selection.start - 2) +
                      selectedText +
                      text.substring(selection.end + 2);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: selection.start - 2 + selectedText.length);
    } else {
      // Add bold
      final newText = text.substring(0, selection.start) +
                      '**$selectedText**' +
                      text.substring(selection.end);
      _controller.text = newText;
      _controller.selection = TextSelection(
        baseOffset: selection.start + 2,
        extentOffset: selection.start + 2 + selectedText.length,
      );
    }
  }

  // Wrap selection with markdown italic syntax
  void _toggleItalic() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final text = _controller.text;
    final selectedText = selection.textInside(text);

    // Check if already italic
    final before = selection.start >= 1 ? text.substring(selection.start - 1, selection.start) : '';
    final after = selection.end + 1 <= text.length ? text.substring(selection.end, selection.end + 1) : '';

    if (before == '*' && after == '*') {
      // Remove italic
      final newText = text.substring(0, selection.start - 1) +
                      selectedText +
                      text.substring(selection.end + 1);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: selection.start - 1 + selectedText.length);
    } else {
      // Add italic
      final newText = text.substring(0, selection.start) +
                      '*$selectedText*' +
                      text.substring(selection.end);
      _controller.text = newText;
      _controller.selection = TextSelection(
        baseOffset: selection.start + 1,
        extentOffset: selection.start + 1 + selectedText.length,
      );
    }
  }

  // Handle automatic list continuation when Enter is pressed
  void _handleListContinuation() {
    // Prevent recursive calls when we modify the text
    if (_isHandlingListContinuation) return;

    final selection = _controller.selection;
    if (!selection.isValid || selection.start != selection.end) return;

    final text = _controller.text;
    final cursorPos = selection.start;
    final currentLength = text.length;

    // Only trigger if text got longer (addition, not deletion)
    // This prevents the handler from triggering when deleting characters
    if (currentLength <= _lastTextLength) {
      _lastTextLength = currentLength;
      return;
    }

    // Only handle newline case (continuing lists)
    if (cursorPos >= 1 && cursorPos <= text.length && text[cursorPos - 1] == '\n') {
      _handleNewlineInList(text, cursorPos);
    }

    _lastTextLength = currentLength;
  }

  // Handle Enter key - continue or exit list
  void _handleNewlineInList(String text, int cursorPos) {
    // Find the previous line (before the newline we just added)
    var prevLineStart = cursorPos - 2; // Start before the newline
    while (prevLineStart > 0 && text[prevLineStart - 1] != '\n') {
      prevLineStart--;
    }

    // Get previous line content
    final prevLineEnd = cursorPos - 1; // The newline position
    if (prevLineStart >= prevLineEnd) return;

    final prevLine = text.substring(prevLineStart, prevLineEnd);

    // Check for bullet list (- or *)
    final bulletMatch = RegExp(r'^([-*]) (.*)$').firstMatch(prevLine);
    if (bulletMatch != null) {
      _isHandlingListContinuation = true;

      final marker = bulletMatch.group(1)!;
      final content = bulletMatch.group(2)!;

      // If previous line was empty bullet, remove it and keep the newline (exit list)
      if (content.isEmpty) {
        final newText = text.substring(0, prevLineStart) + text.substring(prevLineEnd);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: prevLineStart);
        _isHandlingListContinuation = false;
        return;
      }

      // Add bullet marker on new line
      final newText = text.substring(0, cursorPos) + '$marker ' + text.substring(cursorPos);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: cursorPos + 2);
      _isHandlingListContinuation = false;
      return;
    }

    // Check for numbered list (1. 2. etc)
    final numberedMatch = RegExp(r'^(\d+)\. (.*)$').firstMatch(prevLine);
    if (numberedMatch != null) {
      _isHandlingListContinuation = true;

      final number = int.parse(numberedMatch.group(1)!);
      final content = numberedMatch.group(2)!;

      // If previous line was empty numbered item, remove it and keep the newline (exit list)
      if (content.isEmpty) {
        final newText = text.substring(0, prevLineStart) + text.substring(prevLineEnd);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: prevLineStart);
        _isHandlingListContinuation = false;
        return;
      }

      // Add next number on new line
      final nextNumber = number + 1;
      final newText = text.substring(0, cursorPos) + '$nextNumber. ' + text.substring(cursorPos);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: cursorPos + nextNumber.toString().length + 2);
      _isHandlingListContinuation = false;
      return;
    }
  }

  // Detect markdown shortcuts as user types (##, ###, -, *, 1.)
  // This creates a Notion-like experience where typing "## " auto-formats
  void _detectMarkdownShortcuts() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.start != selection.end) return;

    final text = _controller.text;
    final cursorPos = selection.start;

    // Guard against empty text or cursor at start
    if (cursorPos <= 0 || text.isEmpty) return;

    // Find the start of the current line
    var lineStart = cursorPos;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Ensure valid range for substring
    if (lineStart < 0 || lineStart >= cursorPos) return;

    // Get the text from line start to cursor
    final linePrefix = text.substring(lineStart, cursorPos);

    // Only process if we just typed a space after a markdown pattern
    if (!linePrefix.endsWith(' ')) return;

    // Check for heading patterns: #, ##, ###
    final headingMatch = RegExp(r'^(#{1,3}) $').firstMatch(linePrefix);
    if (headingMatch != null) {
      // Keep the heading markers - they're already there
      // No action needed - user typed "## " and we want to keep it as is
      return;
    }

    // Check for list patterns: -, *, 1.
    final listMatch = RegExp(r'^(\d+\.|[-*]) $').firstMatch(linePrefix);
    if (listMatch != null) {
      // Keep the list markers - they're already there
      // No action needed - user typed "- " or "1. " and we want to keep it as is
      return;
    }
  }

  // Show theme and brightness settings modal
  void _showSettingsModal() {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = widget.settingsService.isDark(systemBrightness);

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 400,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.settingsService.getTextColor(isDark),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text('Done', style: TextStyle(color: isDark ? CupertinoColors.activeBlue : CupertinoColors.activeBlue)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Theme mode selector
              Text(
                'Theme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.settingsService.getTextColor(isDark),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: widget.settingsService.themeMode,
                backgroundColor: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey5,
                thumbColor: isDark ? const Color(0xFF3A3A3C) : CupertinoColors.white,
                children: {
                  'system': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('System', style: TextStyle(color: widget.settingsService.getTextColor(isDark))),
                  ),
                  'light': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Light', style: TextStyle(color: widget.settingsService.getTextColor(isDark))),
                  ),
                  'dark': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Dark', style: TextStyle(color: widget.settingsService.getTextColor(isDark))),
                  ),
                },
                onValueChanged: (String? value) async {
                  if (value != null) {
                    await widget.settingsService.setThemeMode(value);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 24),

              // Amber mode toggle - hide on Android/e-ink devices like DC1
              if (!Platform.isAndroid) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amber Text',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: widget.settingsService.getTextColor(isDark),
                      ),
                    ),
                    CupertinoSwitch(
                      value: widget.settingsService.amberMode,
                      activeColor: const Color(0xFFFF6B00),
                      onChanged: (bool value) async {
                        await widget.settingsService.setAmberMode(value);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Brightness slider - hide on macOS
              if (!Platform.isMacOS) ...[
                Text(
                  'Screen Brightness',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: widget.settingsService.getTextColor(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoSlider(
                        value: _brightnessToSlider(widget.settingsService.brightness),
                        min: 0.0, // Full logarithmic range
                        max: 1.0,
                        divisions: 1000, // Smooth control across full range
                        activeColor: isDark ? CupertinoColors.white : CupertinoColors.activeBlue,
                        onChanged: (double sliderValue) async {
                          final brightness = _sliderToBrightness(sliderValue);
                          await widget.settingsService.setBrightness(brightness);
                          await _applyBrightness();
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${(widget.settingsService.brightness * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.settingsService.getTextColor(isDark),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Show actions menu as a dropdown popup
  void _showActionsMenu() {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = widget.settingsService.isDark(systemBrightness);

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        margin: const EdgeInsets.only(top: 60, right: 10),
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            width: 280,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuOption(
                    'Cycle Heading Level',
                    'Cmd+H',
                    () {
                      Navigator.pop(context);
                      _insertHeading();
                    },
                    isDark,
                  ),
                  _buildMenuOption(
                    _isFullWidth ? 'Exit Full Width' : 'Full Width Mode',
                    'Cmd+W',
                    () {
                      Navigator.pop(context);
                      _toggleFullWidth();
                    },
                    isDark,
                  ),
                  _buildMenuOption(
                    'Export to PDF',
                    'Cmd+P',
                    () {
                      Navigator.pop(context);
                      _exportToPdf();
                    },
                    isDark,
                  ),
                  _buildMenuOption(
                    'Export to Markdown',
                    null,
                    () {
                      Navigator.pop(context);
                      _exportToMarkdown();
                    },
                    isDark,
                  ),
                  _buildMenuOption(
                    'Open in Claude Chat',
                    'Cmd+L',
                    () {
                      Navigator.pop(context);
                      _openClaudeChat();
                    },
                    isDark,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(String title, String? shortcut, VoidCallback onTap, bool isDark, {bool isLast = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isLast ? null : Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: widget.settingsService.getTextColor(isDark),
              ),
            ),
            if (shortcut != null)
              Text(
                shortcut,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Get theme icon based on current mode
  IconData _getThemeIcon() {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    switch (widget.settingsService.themeMode) {
      case 'light':
        return CupertinoIcons.sun_max_fill;
      case 'dark':
        return CupertinoIcons.moon_fill;
      case 'system':
      default:
        return systemBrightness == Brightness.dark
            ? CupertinoIcons.moon
            : CupertinoIcons.sun_max;
    }
  }

  // Format date for display in sidebar
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  // Show dialog to edit document title
  Future<void> _editDocumentTitle() async {
    if (_currentDocument == null) return;

    final TextEditingController titleController = TextEditingController(text: _currentDocument!.title);

    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Document Title'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: titleController,
            placeholder: 'Document title',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty) {
                // Update document with custom title by modifying the first line
                final lines = _controller.text.split('\n');
                String newContent;
                if (lines.isEmpty || lines.first.trim().isEmpty) {
                  newContent = newTitle + '\n' + _controller.text;
                } else {
                  // Replace first line with new title
                  lines[0] = newTitle;
                  newContent = lines.join('\n');
                }
                _controller.text = newContent;

                final updatedDoc = _currentDocument!.copyWith(
                  content: newContent,
                  lastModified: DateTime.now(),
                );

                await _storageService.saveCurrentDocument(updatedDoc);
                await _storageService.saveDocument(updatedDoc);
                setState(() {
                  _currentDocument = updatedDoc;
                });
                await _loadAllDocuments();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    titleController.dispose();
  }

  // Convert brightness value (0.0-1.0) to logarithmic slider position (0.0-1.0)
  // Slider mapping: 0-33% = 0-1%, 33-66% = 1-10%, 66-100% = 10-100%
  double _brightnessToSlider(double brightness) {
    if (brightness <= 0.01) {
      // 0-1% brightness maps to 0-33% slider
      return (brightness / 0.01) * 0.33;
    } else if (brightness <= 0.1) {
      // 1-10% brightness maps to 33-66% slider
      return 0.33 + ((brightness - 0.01) / 0.09) * 0.33;
    } else {
      // 10-100% brightness maps to 66-100% slider
      return 0.66 + ((brightness - 0.1) / 0.9) * 0.34;
    }
  }

  // Convert logarithmic slider position (0.0-1.0) to brightness value (0.0-1.0)
  // Slider mapping: 0-33% = 0-1%, 33-66% = 1-10%, 66-100% = 10-100%
  double _sliderToBrightness(double sliderValue) {
    if (sliderValue <= 0.33) {
      // 0-33% slider maps to 0-1% brightness
      return (sliderValue / 0.33) * 0.01;
    } else if (sliderValue <= 0.66) {
      // 33-66% slider maps to 1-10% brightness
      return 0.01 + ((sliderValue - 0.33) / 0.33) * 0.09;
    } else {
      // 66-100% slider maps to 10-100% brightness
      return 0.1 + ((sliderValue - 0.66) / 0.34) * 0.9;
    }
  }

  // Build reading view with formatted markdown
  Widget _buildReadingView(Color textColor) {
    final lines = _controller.text.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      // Handle headings with proper sizes
      if (line.startsWith('### ')) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(
          Text(
            line.substring(4),
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.4,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        widgets.add(const SizedBox(height: 18));
        widgets.add(
          Text(
            line.substring(3),
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.4,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 10));
      } else if (line.startsWith('# ')) {
        widgets.add(const SizedBox(height: 20));
        widgets.add(
          Text(
            line.substring(2),
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.4,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 12));
      } else {
        // Regular text - parse inline formatting
        widgets.add(
          Text.rich(
            _parseInlineMarkdown(line, textColor),
            style: TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 18,
              height: 1.8,
              color: textColor,
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  // Parse inline markdown (bold, italic)
  TextSpan _parseInlineMarkdown(String text, Color textColor) {
    final spans = <TextSpan>[];
    var currentIndex = 0;

    // Simple regex-based parsing for **bold** and *italic*
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    final italicRegex = RegExp(r'\*(.+?)\*');

    while (currentIndex < text.length) {
      // Check for bold
      final boldMatch = boldRegex.firstMatch(text.substring(currentIndex));
      final italicMatch = italicRegex.firstMatch(text.substring(currentIndex));

      if (boldMatch != null && (italicMatch == null || boldMatch.start <= italicMatch.start)) {
        // Add text before bold
        if (boldMatch.start > 0) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, currentIndex + boldMatch.start),
            style: TextStyle(color: textColor),
          ));
        }

        // Add bold text
        spans.add(TextSpan(
          text: boldMatch.group(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ));

        currentIndex += boldMatch.end;
      } else if (italicMatch != null) {
        // Add text before italic
        if (italicMatch.start > 0) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, currentIndex + italicMatch.start),
            style: TextStyle(color: textColor),
          ));
        }

        // Add italic text
        spans.add(TextSpan(
          text: italicMatch.group(1),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: textColor,
          ),
        ));

        currentIndex += italicMatch.end;
      } else {
        // No more formatting, add remaining text
        spans.add(TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: textColor),
        ));
        break;
      }
    }

    return TextSpan(children: spans.isEmpty ? [TextSpan(text: text, style: TextStyle(color: textColor))] : spans);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isHorizontal = screenWidth > screenHeight;

    // On horizontal screens (Mac/desktop), use a narrow fixed width
    // On vertical screens (phone), use percentage
    final contentWidth = _isFullWidth
        ? screenWidth
        : isHorizontal
            ? 650.0 // Fixed narrow width for horizontal screens
            : screenWidth * 0.85; // Percentage for vertical screens

    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = widget.settingsService.isDark(systemBrightness);
    final textColor = widget.settingsService.getTextColor(isDark);
    final placeholderColor = CupertinoColors.systemGrey;
    final selectionColor = isDark
        ? (widget.settingsService.amberMode
            ? const Color(0xFFFF6B00).withOpacity(0.4) // Amber selection
            : CupertinoColors.white.withOpacity(0.3)) // White selection
        : CupertinoColors.activeBlue.withOpacity(0.3);

    return MouseRegion(
      onHover: (_) {
        // Show UI on mouse movement
        if (!_showUI) {
          setState(() {
            _showUI = true;
          });
        }
      },
      child: GestureDetector(
        onPanUpdate: (_) {
          // Show UI on swipe/pan
          if (!_showUI) {
            setState(() {
              _showUI = true;
            });
          }
        },
        child: CupertinoPageScaffold(
          navigationBar: _showUI
              ? CupertinoNavigationBar(
                  // Increase height on Android by adding vertical padding
                  padding: EdgeInsetsDirectional.only(
                    top: Platform.isAndroid ? 12 : 0,
                    bottom: Platform.isAndroid ? 12 : 0,
                  ),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          _showSidebar ? CupertinoIcons.sidebar_left : CupertinoIcons.list_bullet,
                          color: widget.settingsService.getTextColor(isDark),
                        ),
                        onPressed: () {
                          setState(() {
                            _showSidebar = !_showSidebar;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          CupertinoIcons.add,
                          color: widget.settingsService.getTextColor(isDark),
                        ),
                        onPressed: _createNewDocument,
                      ),
                    ],
                  ),
                  middle: GestureDetector(
                    onTap: _editDocumentTitle,
                    child: Text(
                      _currentDocument?.title ?? 'Untitled',
                      style: TextStyle(color: widget.settingsService.getTextColor(isDark)),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          _showPreview ? CupertinoIcons.pencil : CupertinoIcons.eye,
                          color: widget.settingsService.getTextColor(isDark),
                        ),
                        onPressed: () {
                          setState(() {
                            _showPreview = !_showPreview;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          _getThemeIcon(),
                          color: widget.settingsService.getTextColor(isDark),
                        ),
                        onPressed: _showSettingsModal,
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          CupertinoIcons.ellipsis,
                          color: widget.settingsService.getTextColor(isDark),
                        ),
                        onPressed: _showActionsMenu,
                      ),
                    ],
                  ),
                )
              : null,
          child: Stack(
            children: [
              // Main editor - Remove top/bottom SafeArea padding for edge-to-edge content
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Center(
                    child: Container(
                      width: contentWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0, // Remove unnecessary top/bottom margins
                      ),
                    child: Shortcuts(
                      shortcuts: <ShortcutActivator, Intent>{
                        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB): const BoldIntent(),
                        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyI): const ItalicIntent(),
                        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyH): const HeadingIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          BoldIntent: CallbackAction<BoldIntent>(
                            onInvoke: (BoldIntent intent) {
                              _toggleBold();
                              return null;
                            },
                          ),
                          ItalicIntent: CallbackAction<ItalicIntent>(
                            onInvoke: (ItalicIntent intent) {
                              _toggleItalic();
                              return null;
                            },
                          ),
                          HeadingIntent: CallbackAction<HeadingIntent>(
                            onInvoke: (HeadingIntent intent) {
                              _insertHeading();
                              return null;
                            },
                          ),
                        },
                        child: Theme(
                          data: ThemeData(
                            textSelectionTheme: TextSelectionThemeData(
                              selectionColor: selectionColor,
                              cursorColor: textColor,
                            ),
                          ),
                          child: _showPreview
                            ? _buildReadingView(textColor)
                            : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification notification) {
                          // Dismiss keyboard when scrolling up by about half a page on Android
                          if (notification is ScrollUpdateNotification) {
                            final currentOffset = notification.metrics.pixels;
                            final delta = currentOffset - _lastScrollOffset;

                            // If scrolling up (negative delta) by ~half page (300px), dismiss keyboard
                            if (delta < -300 && _focusNode.hasFocus) {
                              _focusNode.unfocus();
                            }

                            _lastScrollOffset = currentOffset;
                          }
                          return false;
                        },
                        child: CupertinoTextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          expands: true,
                          autofocus: true,
                          decoration: const BoxDecoration(),
                          style: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 18,
                            height: 1.8, // Increased from 1.6 for better paragraph spacing
                            color: textColor,
                          ),
                          cursorColor: textColor,
                          placeholder: 'Start writing...',
                          placeholderStyle: TextStyle(
                            fontFamily: 'Times New Roman',
                            fontSize: 18,
                            height: 1.8, // Increased from 1.6 for better paragraph spacing
                            color: placeholderColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

              // Sidebar backdrop - tap outside to dismiss
              if (_showSidebar)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSidebar = false;
                      });
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),

              // Sidebar
              if (_showSidebar)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      // Swipe left to dismiss
                      if (details.primaryVelocity! < -300) {
                        setState(() {
                          _showSidebar = false;
                        });
                      }
                    },
                    child: Container(
                      width: 300,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'Documents',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: widget.settingsService.getTextColor(isDark),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _allDocuments.length,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemBuilder: (context, index) {
                                  final doc = _allDocuments[index];
                                  final isCurrentDoc = doc.id == _currentDocument?.id;

                                  return GestureDetector(
                                    onTap: () => _switchToDocument(doc),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isCurrentDoc
                                            ? (isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isCurrentDoc ? FontWeight.w500 : FontWeight.normal,
                                              color: widget.settingsService.getTextColor(isDark),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDate(doc.lastModified),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
