import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../utils/text_direction_helper.dart';

/// Service to generate and share certificate PDFs
class CertificatePdfService {
  /// Generate and save certificate PDF
  /// Returns the file path of the saved PDF
  static Future<String> generateAndSaveCertificate({
    required String userName,
    required String topic,
    required DateTime date,
  }) async {
    final pdf = await _createCertificatePdf(
      userName: userName,
      topic: topic,
      date: date,
    );

    // Get Downloads directory
    final directory = await _getDownloadDirectory();
    final fileName = 'ZS_Certificate_${topic.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(date)}.pdf';
    final filePath = '${directory.path}/$fileName';

    // Save PDF
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  /// Share certificate PDF
  static Future<void> shareCertificate({
    required String userName,
    required String topic,
    required DateTime date,
  }) async {
    final pdf = await _createCertificatePdf(
      userName: userName,
      topic: topic,
      date: date,
    );

    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final fileName = 'ZS_Certificate_${topic.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(date)}.pdf';
    final filePath = '${tempDir.path}/$fileName';

    // Save PDF temporarily
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Share the file
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'I earned my $topic certificate from Zaroori Sawal!',
    );
  }

  /// Create the certificate PDF document
  static Future<pw.Document> _createCertificatePdf({
    required String userName,
    required String topic,
    required DateTime date,
  }) async {
    final pdf = pw.Document();

    // Load images from assets
    final logoBytes = await rootBundle.load('assets/certificate/logo.png');
    final signatureBytes = await rootBundle.load('assets/certificate/signature.png');
    final backgroundBytes = await rootBundle.load('assets/certificate/background.png');

    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final signatureImage = pw.MemoryImage(signatureBytes.buffer.asUint8List());
    final backgroundImage = pw.MemoryImage(backgroundBytes.buffer.asUint8List());

    // Detect text direction based on content (topic name)
    final isRtlContent = TextDirectionHelper.containsRtlText(topic);
    final textDirection = isRtlContent ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final textAlign = isRtlContent ? pw.TextAlign.right : pw.TextAlign.left;

    final formattedDate = DateFormat('MMMM dd, yyyy').format(date);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Background
              pw.Positioned.fill(
                child: pw.Image(
                  backgroundImage,
                  fit: pw.BoxFit.cover,
                ),
              ),
              // Content - Centered text
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 40, right: 40, top: 40, bottom: 120),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      // Certificate Title
                      pw.Text(
                        'CERTIFICATE',
                        style: pw.TextStyle(
                          fontSize: 48,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1a365d'),
                        ),
                        textDirection: textDirection,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'OF ACHIEVEMENT',
                        style: pw.TextStyle(
                          fontSize: 24,
                          color: PdfColor.fromHex('#2c5282'),
                        ),
                        textDirection: textDirection,
                      ),
                      pw.SizedBox(height: 30),
                      
                      // Presented to text
                      pw.Text(
                        'This Certificate is Presented to',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColor.fromHex('#4a5568'),
                        ),
                        textDirection: textDirection,
                      ),
                      pw.SizedBox(height: 20),
                      
                      // User Name
                      pw.Text(
                        userName,
                        style: pw.TextStyle(
                          fontSize: 36,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColor.fromHex('#1a365d'),
                          decoration: pw.TextDecoration.underline,
                        ),
                        textDirection: TextDirectionHelper.containsRtlText(userName) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                      ),
                      pw.SizedBox(height: 30),
                      
                      // Description
                      pw.Text(
                        'For passing the ZS "$topic"',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColor.fromHex('#2d3748'),
                        ),
                        textDirection: textDirection,
                        textAlign: textAlign,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'course on $formattedDate.',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColor.fromHex('#2d3748'),
                        ),
                        textDirection: textDirection,
                        textAlign: textAlign,
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom section with logo and signature - positioned at bottom
              pw.Positioned(
                left: 40,
                right: 80,
                bottom: 40,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Logo - Increased size for professional appearance
                    pw.Image(
                      logoImage,
                      width: 160,
                      height: 80,
                      fit: pw.BoxFit.contain,
                    ),
                    // Signature - Moved left to avoid corner overlap
                    pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Image(
                          signatureImage,
                          width: 140,
                          height: 55,
                          fit: pw.BoxFit.contain,
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: 140,
                          height: 1,
                          color: PdfColor.fromHex('#1a365d'),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'M Junaid Gohar',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#1a365d'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Get appropriate directory for saving files
  static Future<Directory> _getDownloadDirectory() async {
    // Try to get Downloads directory
    if (Platform.isAndroid) {
      // For Android 10+, use app documents directory
      // For older Android, try to use Downloads
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Create a ZarooriSawal folder in Downloads
        final downloadsPath = '${directory.parent.path}/Download/ZarooriSawal';
        final downloadsDir = Directory(downloadsPath);
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      }
    }
    
    // Fallback to app documents directory
    final directory = await getApplicationDocumentsDirectory();
    final certDir = Directory('${directory.path}/Certificates');
    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }
    return certDir;
  }
}
