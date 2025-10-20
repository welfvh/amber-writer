// Main editor screen - Minimalist markdown text editor with iOS-style UI
// Features: Full-width mode, PDF export, Claude chat integration, keyboard shortcuts

import 'package:flutter/cupertino.dart';
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

  // Insert markdown heading
  void _insertHeading() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (selection.start == -1) return;

    // Find start of current line
    var lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Check if line already has heading markers
    if (lineStart < text.length && text[lineStart] == '#') {
      // Already has heading, do nothing or remove it
      return;
    }

    // Insert ## at start of line
    final newText = text.substring(0, lineStart) + '## ' + text.substring(lineStart);

    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + 3,
    );
  }

  // Show theme and brightness settings modal
  void _showSettingsModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
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
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Theme mode selector
              const Text(
                'Theme',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              CupertinoSegmentedControl<String>(
                groupValue: widget.settingsService.themeMode,
                children: const {
                  'system': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('System'),
                  ),
                  'light': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Light'),
                  ),
                  'dark': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Dark'),
                  ),
                },
                onValueChanged: (String value) async {
                  await widget.settingsService.setThemeMode(value);
                  setState(() {});
                },
              ),
              const SizedBox(height: 24),

              // Brightness slider
              const Text(
                'Screen Brightness',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CupertinoSlider(
                      value: widget.settingsService.brightness,
                      min: 0.0,
                      max: 0.02,
                      divisions: 200, // 0.1% increments
                      onChanged: (double value) async {
                        await widget.settingsService.setBrightness(value);
                        await _applyBrightness();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${(widget.settingsService.brightness * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14),
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
        title: const Text('Actions'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _toggleFullWidth();
            },
            child: Text(_isFullWidth ? 'Exit Full Width' : 'Full Width Mode'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _insertHeading();
            },
            child: const Text('Insert Heading (##)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _exportToPdf();
            },
            child: const Text('Export to PDF'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openClaudeChat();
            },
            child: const Text('Open in Claude Chat'),
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
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final placeholderColor = CupertinoColors.systemGrey;

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
    );
  }
}
