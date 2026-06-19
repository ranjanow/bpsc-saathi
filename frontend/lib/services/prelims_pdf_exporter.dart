import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ecosystem_model.dart';

/// Utility class for generating and exporting BPSC exam pools as PDF documents.
class PrelimsPdfExporter {
  /// Exports the given [questions] under the provided [topic] as a styled A4 PDF.
  /// Automatically triggers the native OS share/print dialog.
  static Future<void> exportEcosystem({
    required String topic,
    required List<GeneratedQuestion> questions,
    bool isHindi = false,
  }) async {
    if (questions.isEmpty) return;

    final pdf = pw.Document();

    // 1. Load standard fonts for safe cross-platform rendering
    final robotoRegular = await PdfGoogleFonts.robotoRegular();
    final robotoBold = await PdfGoogleFonts.robotoBold();
    
    // Load Hindi-compatible fonts
    final hindiRegular = await PdfGoogleFonts.notoSansDevanagariRegular();
    final hindiBold = await PdfGoogleFonts.notoSansDevanagariBold();

    // Determine primary font and fallback based on language selection
    final primaryRegular = isHindi ? hindiRegular : robotoRegular;
    final primaryBold = isHindi ? hindiBold : robotoBold;
    final fallbackFonts = isHindi ? [robotoRegular] : [hindiRegular];

    final theme = pw.ThemeData.withFont(
      base: primaryRegular,
      bold: primaryBold,
      fontFallback: fallbackFonts,
    );

    // 2. Configure A4 page layout with 2.0cm margins
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(2.0 * PdfPageFormat.cm),
        theme: theme,
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'BPSC Prelims Tracker',
                    style: pw.TextStyle(
                      font: robotoBold, // Always English
                      fontSize: 14,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    topic,
                    style: pw.TextStyle(
                      font: primaryBold,
                      fontFallback: fallbackFonts,
                      fontSize: 14,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 16),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: robotoRegular,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          final List<pw.Widget> elements = [];

          // 3. Iterate questions — The KeepTogether Rule
          for (int i = 0; i < questions.length; i++) {
            final q = questions[i];
            
            elements.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Question Stem
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Q${i + 1}. ',
                          style: pw.TextStyle(
                            font: robotoBold, 
                            fontSize: 11
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            isHindi ? q.questionHi : q.questionEn,
                            style: pw.TextStyle(
                              font: primaryBold, 
                              fontFallback: fallbackFonts,
                              fontSize: 11
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),

                    // Options List
                    ...List.generate(isHindi ? q.optionsHi.length : q.optionsEn.length, (optIdx) {
                      final optionLetters = ['A', 'B', 'C', 'D', 'E'];
                      final letter = optIdx < optionLetters.length
                          ? optionLetters[optIdx]
                          : '';
                      final isCorrect = optIdx == q.correctOptionIndex;
                      final optionText = isHindi ? q.optionsHi[optIdx] : q.optionsEn[optIdx];

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6, left: 16),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '$letter. ',
                              style: pw.TextStyle(
                                font: isCorrect ? robotoBold : robotoRegular,
                                fontSize: 11,
                                color: isCorrect
                                    ? PdfColors.green700
                                    : PdfColors.black,
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                optionText,
                                style: pw.TextStyle(
                                  font: isCorrect ? primaryBold : primaryRegular,
                                  fontFallback: fallbackFonts,
                                  fontSize: 11,
                                  color: isCorrect
                                      ? PdfColors.green700
                                      : PdfColors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    pw.SizedBox(height: 6),

                    // Explanation Box (Shaded with left border)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(
                          left: 16, top: 4, bottom: 20),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFF8F9FA), // light gray
                        border: pw.Border(
                          left: pw.BorderSide(
                              color: PdfColors.blue600, width: 3),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Explanation:',
                            style: pw.TextStyle(
                              font: robotoBold,
                              fontSize: 10,
                              color: PdfColors.blue800,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            isHindi ? q.explanationHi : q.explanationEn,
                            style: pw.TextStyle(
                              font: primaryRegular,
                              fontFallback: fallbackFonts,
                              fontSize: 10,
                              lineSpacing: 1.5,
                              color: PdfColors.grey900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            );
          }

          return elements;
        },
      ),
    );

    // 4. Generate and trigger OS share/print
    final bytes = await pdf.save();
    
    // Sanitize filename
    final safeTopic = topic.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'BPSC_Review_$safeTopic.pdf',
    );
  }
}