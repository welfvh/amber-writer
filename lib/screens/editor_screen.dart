// Main editor screen - Minimalist markdown text editor with iOS-style UI
// Features: Full-width mode, PDF export, Claude chat integration, keyboard shortcuts

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../models/document.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../services/settings_service.dart';

class EditorScreen extends StatefulWidget {
  final SettingsService settingsService;

  const EditorScreen({super.key, required this.settingsService});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final StorageService _storageService = StorageService();
  final PdfService _pdfService = PdfService();
  final FocusNode _focusNode = FocusNode();

  Document? _currentDocument;
  bool _isFullWidth = false;
  bool _showPreview = false;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
    _applyBrightness();

    // Auto-save on text change and hide UI when typing
    _controller.addListener(() {
      _autoSave();
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

  // Auto-save document
  Future<void> _autoSave() async {
    if (_currentDocument == null) return;

    final updatedDoc = _currentDocument!.copyWith(
      content: _controller.text,
      lastModified: DateTime.now(),
    );

    await _storageService.saveCurrentDocument(updatedDoc);
    setState(() {
      _currentDocument = updatedDoc;
    });
  }

  // Toggle full-width mode
  void _toggleFullWidth() {
    setState(() {
      _isFullWidth = !_isFullWidth;
    });
  }

  // Export to PDF
  Future<void> _exportToPdf() async {
    if (_currentDocument == null) return;

    try {
      await _pdfService.exportToPdf(
        _currentDocument!.content,
        _currentDocument!.title,
      );

      _showMessage('PDF exported successfully');
    } catch (e) {
      _showMessage('Failed to export PDF: $e');
    }
  }

  // Open Claude chat with document
  Future<void> _openClaudeChat() async {
    if (_currentDocument == null || _currentDocument!.content.isEmpty) {
      _showMessage('Document is empty');
      return;
    }

    // Copy content to clipboard first
    await Clipboard.setData(ClipboardData(text: _currentDocument!.content));

    // Open Claude.ai
    final uri = Uri.parse('https://claude.ai/new');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _showMessage('Document copied to clipboard. Paste in Claude chat.');
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
                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
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
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
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
                    child: Text('System', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                  ),
                  'light': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Light', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
                  ),
                  'dark': Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Dark', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
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

              // Amber mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amber Text',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
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

              // Brightness slider
              Text(
                'Screen Brightness',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CupertinoSlider(
                      value: widget.settingsService.brightness,
                      min: 0.0,
                      max: 0.02,
                      divisions: 2000, // 0.01% increments (max granularity)
                      activeColor: isDark ? CupertinoColors.white : CupertinoColors.activeBlue,
                      onChanged: (double value) async {
                        await widget.settingsService.setBrightness(value);
                        await _applyBrightness();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${(widget.settingsService.brightness * 100).toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? CupertinoColors.white : CupertinoColors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show actions menu
  void _showActionsMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Format & Actions'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _insertHeading();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Cycle Heading Level'),
                Text('Cmd+H', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _toggleFullWidth();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isFullWidth ? 'Exit Full Width' : 'Full Width Mode'),
                const Text('Cmd+W', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _exportToPdf();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Export to PDF'),
                Text('Cmd+P', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openClaudeChat();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Open in Claude Chat'),
                Text('Cmd+L', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
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
                  middle: Text(_currentDocument?.title ?? 'Untitled'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(_getThemeIcon()),
                        onPressed: _showSettingsModal,
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.ellipsis),
                        onPressed: _showActionsMenu,
                      ),
                    ],
                  ),
                )
              : null,
          child: SafeArea(
            child: Center(
              child: Container(
                width: contentWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: _showUI ? 20 : 60,
                ),
                child: Theme(
                  data: ThemeData(
                    textSelectionTheme: TextSelectionThemeData(
                      selectionColor: selectionColor,
                      cursorColor: textColor,
                    ),
                  ),
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
                      height: 1.6,
                      color: textColor,
                    ),
                    cursorColor: textColor,
                    placeholder: 'Start writing...',
                    placeholderStyle: TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 18,
                      height: 1.6,
                      color: placeholderColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
