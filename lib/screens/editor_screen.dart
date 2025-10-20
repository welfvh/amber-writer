// Main editor screen - Minimalist markdown text editor with iOS-style UI
// Features: Full-width mode, PDF export, Claude chat integration, keyboard shortcuts

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/document.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadDocument();

    // Auto-save on text change
    _controller.addListener(() {
      _autoSave();
    });
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = _isFullWidth ? screenWidth : screenWidth * 0.85;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_currentDocument?.title ?? 'Untitled'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.ellipsis_circle),
          onPressed: _showActionsMenu,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            width: contentWidth,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: CupertinoTextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              autofocus: true,
              decoration: const BoxDecoration(),
              style: const TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 18,
                height: 1.6,
                color: CupertinoColors.black,
              ),
              placeholder: 'Start writing...',
              placeholderStyle: const TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 18,
                height: 1.6,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
