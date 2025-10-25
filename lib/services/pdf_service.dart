// PDF export service for converting markdown documents to PDF format
// with Times New Roman font and elegant typography

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:markdown/markdown.dart' as md;

class PdfService {
  // Build PDF widgets from markdown content
  List<pw.Widget> _buildPdfWidgets(List<String> lines, String? title) {
    final widgets = <pw.Widget>[];

    // Add title if provided
    if (title != null && title.isNotEmpty && title != 'Untitled') {
      widgets.add(
        pw.Header(
          level: 0,
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 20));
    }

    // Process content line by line
    for (var line in lines) {
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 12));
        continue;
      }

      // Handle headings
      if (line.startsWith('## ')) {
        widgets.add(pw.SizedBox(height: 16));
        widgets.add(
          pw.Text(
            line.substring(3),
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 8));
      } else if (line.startsWith('# ')) {
        widgets.add(pw.SizedBox(height: 20));
        widgets.add(
          pw.Text(
            line.substring(2),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 10));
      } else {
        // Regular paragraph
        widgets.add(
          pw.Paragraph(
            text: line,
            style: const pw.TextStyle(
              fontSize: 12,
              lineSpacing: 1.6,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // Export document to PDF with elegant typography, returns the saved file path
  Future<String?> exportToPdf(String content, String title) async {
    final pdf = pw.Document();
    final lines = content.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(72), // 1 inch margins
        build: (context) => _buildPdfWidgets(lines, title),
      ),
    );

    // Save PDF and return path
    return await _savePdf(pdf, title);
  }

  // Save PDF using file picker dialog, returns the saved file path
  Future<String?> _savePdf(pw.Document pdf, String title) async {
    final fileName = '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf';

    // Show save file dialog - defaults to Downloads folder
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileName,
      initialDirectory: Platform.isMacOS
          ? '${Platform.environment['HOME']}/Downloads'
          : null,
    );

    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsBytes(await pdf.save());
      return outputPath;
    }
    return null;
  }

  // Print PDF directly
  Future<void> printDocument(String content, String title) async {
    final pdf = pw.Document();
    final lines = content.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(72),
        build: (context) => _buildPdfWidgets(lines, null), // Don't include title for print
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
