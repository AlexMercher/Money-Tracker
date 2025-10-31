import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import '../models/friend.dart';
import '../models/transaction.dart';
import 'hive_service.dart';

/// Service for generating and managing PDF transaction reports
class PdfService {
  static const String _pdfFolderName = 'MoneyTrack_PDFs';

  /// Get the directory where PDFs are stored
  static Future<Directory> getPdfDirectory() async {
    Directory? baseDir;
    
    if (Platform.isAndroid) {
      // For Android, use external storage
      baseDir = await getExternalStorageDirectory();
      if (baseDir != null) {
        final pdfDir = Directory('${baseDir.path}/$_pdfFolderName');
        if (!await pdfDir.exists()) {
          await pdfDir.create(recursive: true);
        }
        return pdfDir;
      }
    }
    
    // Fallback to application documents directory
    baseDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${baseDir.path}/$_pdfFolderName');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  /// Check and request storage permissions
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }
      
      // For Android 13+, try manageExternalStorage
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      
      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }
    
    // iOS doesn't need explicit permission for app documents
    return true;
  }

  /// Find existing PDF for a friend by name
  static Future<File?> _findExistingPdfForFriend(String friendName) async {
    try {
      final pdfDir = await getPdfDirectory();
      if (!await pdfDir.exists()) {
        return null;
      }

      final files = pdfDir.listSync()
          .where((file) => file.path.endsWith('.pdf'))
          .where((file) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            final normalizedFriendName = friendName.replaceAll(' ', '_');
            return fileName.startsWith(normalizedFriendName);
          })
          .toList();

      if (files.isEmpty) return null;

      // Return the most recent PDF for this friend
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return File(files.first.path);
    } catch (e) {
      print('Error finding existing PDF: $e');
      return null;
    }
  }

  /// Generate PDF for a friend's transaction history
  /// Returns the file if successful, null otherwise
  /// Automatically replaces old PDF if no new transactions since last export
  static Future<File?> generateTransactionPdf(Friend friend) async {
    try {
      // Request permissions
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      // Get user profile
      final user = await HiveService.getUserProfile();
      final userName = user?.name ?? 'You';

      // Check for existing PDFs for this friend
      final existingPdf = await _findExistingPdfForFriend(friend.name);
      
      if (existingPdf != null) {
        // Check if there are new transactions since last PDF
        final lastPdfTime = existingPdf.lastModifiedSync();
        final hasNewTransactions = friend.transactions.any(
          (t) => t.date.isAfter(lastPdfTime),
        );
        
        if (!hasNewTransactions) {
          // No new transactions, return existing PDF path in error
          throw Exception('PDF_EXISTS:${existingPdf.path}');
        }
        
        // Has new transactions, delete old PDF before creating new one
        await existingPdf.delete();
      }

      final pdf = pw.Document();
      final now = DateTime.now();
      final dateFormatter = DateFormat('dd MMM yyyy');
      final timeFormatter = DateFormat('hh:mm a');

      // Calculate totals
      double totalLent = 0;
      double totalBorrowed = 0;
      for (var transaction in friend.transactions) {
        if (transaction.type == TransactionType.lent) {
          totalLent += transaction.amount;
        } else {
          totalBorrowed += transaction.amount;
        }
      }

      // Determine who owes whom
      String balanceLabel;
      if (friend.netBalance >= 0) {
        balanceLabel = '${friend.name} Owes';
      } else {
        balanceLabel = '$userName Owes';
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MoneyTrack',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Transaction Report',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Friend Info Card
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green200, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Friend',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              friend.name,
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green900,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Net Balance',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Rs. ${friend.netBalance.abs().toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: friend.netBalance >= 0
                                    ? PdfColors.green700
                                    : PdfColors.red700,
                              ),
                            ),
                            pw.Text(
                              balanceLabel,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(color: PdfColors.green200),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // From friend's perspective: swap labels and colors
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Total Borrowed', style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Rs. ${totalLent.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red700,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Total Lent', style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Rs. ${totalBorrowed.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green700,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Transactions', style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              '${friend.transactions.length}',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Transactions Header
              pw.Text(
                'Transaction History',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 12),

              // Transactions Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableCell('Date', isHeader: true),
                      _buildTableCell('Description', isHeader: true),
                      _buildTableCell('Type', isHeader: true),
                      _buildTableCell('Amount', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Transaction Rows (reversed to show recent first)
                  ...friend.transactions.reversed.map((transaction) {
                    // For friend's perspective: swap lent/borrowed
                    // If we lent to friend → friend borrowed from us
                    // If we borrowed from friend → friend lent to us
                    final isLent = transaction.type == TransactionType.lent;
                    final friendPerspectiveType = isLent ? 'Borrowed' : 'Lent';
                    final friendPerspectiveColor = isLent ? PdfColors.red700 : PdfColors.green700;
                    
                    return pw.TableRow(
                      children: [
                        _buildTableCell(dateFormatter.format(transaction.date)),
                        _buildTableCell(
                          transaction.note.isNotEmpty ? transaction.note : 'No note',
                        ),
                        _buildTableCell(
                          friendPerspectiveType,
                          color: friendPerspectiveColor,
                        ),
                        _buildTableCell(
                          'Rs. ${transaction.amount.toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                          color: friendPerspectiveColor,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 24),

              // Payment Information (if friend owes you and you have payment details)
              if (friend.netBalance > 0 && (user?.phoneNumber.isNotEmpty == true || user?.upiId.isNotEmpty == true)) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.blue200, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue100,
                              borderRadius: pw.BorderRadius.circular(20),
                            ),
                            child: pw.Icon(
                              const pw.IconData(0xe63c), // payment icon
                              color: PdfColors.blue700,
                              size: 16,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            'Payment Information',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      if (user?.phoneNumber.isNotEmpty == true) ...[
                        pw.Row(
                          children: [
                            pw.Text(
                              'Phone (UPI): ',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              '+91 ${user!.phoneNumber}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                      ],
                      if (user?.upiId.isNotEmpty == true) ...[
                        pw.Row(
                          children: [
                            pw.Text(
                              'UPI ID: ',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              user!.upiId,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                
                // Polite message
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'Hey ${friend.name}!\n\n'
                    'Hope you are doing well! Just a gentle reminder about the amount mentioned above. '
                    'Whenever it is convenient for you, I would really appreciate it if you could settle it. '
                    'You can use the payment details above for easy transfer.\n\n'
                    'Thanks a lot for your understanding!',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey800,
                      height: 1.5,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on ${dateFormatter.format(now)} at ${timeFormatter.format(now)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'MoneyTrack App',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Save PDF
      final pdfDir = await getPdfDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = '${friend.name.replaceAll(' ', '_')}_$timestamp.pdf';
      final file = File('${pdfDir.path}/$fileName');
      
      await file.writeAsBytes(await pdf.save());
      
      return file;
    } catch (e) {
      // Re-throw PDF_EXISTS exception to be handled by caller
      if (e.toString().contains('PDF_EXISTS:')) {
        rethrow;
      }
      print('Error generating PDF: $e');
      return null;
    }
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.black : PdfColors.grey800),
        ),
        textAlign: align,
      ),
    );
  }

  /// Get list of all saved PDFs
  static Future<List<FileSystemEntity>> getSavedPdfs() async {
    try {
      final pdfDir = await getPdfDirectory();
      if (!await pdfDir.exists()) {
        return [];
      }

      final files = pdfDir.listSync()
          .where((file) => file.path.endsWith('.pdf'))
          .toList();
      
      // Sort by modification date, newest first
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      print('Error getting saved PDFs: $e');
      return [];
    }
  }

  /// Delete a PDF file
  static Future<bool> deletePdf(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting PDF: $e');
      return false;
    }
  }

  /// Get file size in a readable format
  static String getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Open a PDF file with default PDF viewer
  static Future<bool> openPdf(String filePath) async {
    try {
      print('DEBUG openPdf: Attempting to open file at: $filePath');
      
      // Check if file exists first
      final file = File(filePath);
      if (!await file.exists()) {
        print('DEBUG openPdf: File does not exist at path: $filePath');
        return false;
      }
      
      print('DEBUG openPdf: File exists, size: ${await file.length()} bytes');
      
      final result = await OpenFile.open(filePath);
      print('DEBUG openPdf: OpenFile result type: ${result.type}');
      print('DEBUG openPdf: OpenFile result message: ${result.message}');
      
      return result.type == ResultType.done;
    } catch (e) {
      print('ERROR opening PDF: $e');
      return false;
    }
  }
}

