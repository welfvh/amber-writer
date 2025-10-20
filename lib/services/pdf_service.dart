// PDF export service for converting markdown documents to PDF format
// with Times New Roman font and elegant typography

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:markdown/markdown.dart' as md;

class PdfService {
  // Export document to PDF with elegant typography
  Future<void> exportToPdf(String content, String title) async {
    final pdf = pw.Document();

    // Parse markdown to extract structure
    final lines = content.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(72), // 1 inch margins
        build: (context) {
          final widgets = <pw.Widget>[];

          // Add title
          if (title.isNotEmpty && title != 'Untitled') {
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
        },
      ),
    );

    // Save and share PDF
    await _savePdf(pdf, title);
  }

  // Save PDF to temporary directory and share
  Future<void> _savePdf(pw.Document pdf, String title) async {
    final output = await getTemporaryDirectory();
    final fileName = '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf';
    final file = File('${output.path}/$fileName');

    await file.writeAsBytes(await pdf.save());

    // Share PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: title,
      text: 'Exported from Amber Writer',
    );
  }

  // Print PDF directly
  Future<void> printDocument(String content, String title) async {
    final pdf = pw.Document();

    final lines = content.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(72),
        build: (context) {
          return lines.map((line) {
            if (line.isEmpty) return pw.SizedBox(height: 12);

            if (line.startsWith('## ')) {
              return pw.Text(
                line.substring(3),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              );
            } else if (line.startsWith('# ')) {
              return pw.Text(
                line.substring(2),
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              );
            }

            return pw.Paragraph(
              text: line,
              style: const pw.TextStyle(
                fontSize: 12,
                lineSpacing: 1.6,
              ),
            );
          }).toList();
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
