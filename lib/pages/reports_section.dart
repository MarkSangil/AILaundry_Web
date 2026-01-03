import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/report_service.dart';
import '../utils/error_utils.dart';
// Reports Section
class ReportsSection extends StatefulWidget {
  const ReportsSection({super.key});

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  final supabase = Supabase.instance.client;
  final ReportService _reportService = ReportService(Supabase.instance.client);
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _generateDailyReport() async {
    setState(() => _isGenerating = true);
    try {
      final report = await _reportService.getDailyReport(_selectedDate);
      if (mounted) {
        _showReportDialog(
          'Daily Report - ${_selectedDate.toString().split(' ')[0]}',
          report,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: ${safeErrorToString(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _viewMonthlyReports() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    setState(() => _isGenerating = true);
    try {
      // Get all items for the current month
      final itemsResponse = await supabase
          .from('clothes')
          .select()
          .gte('created_at', firstDayOfMonth.toIso8601String())
          .lte('created_at', lastDayOfMonth.toIso8601String());

      final items = List<Map<String, dynamic>>.from(itemsResponse);
      
      final report = {
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'scanned': items.length,
        'approved': items.where((i) => i['status'] == 'approved').length,
        'pending': items.where((i) => i['status'] == 'pending_check').length,
        'returned': items.where((i) => i['status'] == 'returned').length,
        'voided': items.where((i) => i['status'] == 'voided').length,
        'items': items,
      };

      if (mounted) {
        _showReportDialog('Monthly Report - ${report['month']}', report);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading monthly report: ${safeErrorToString(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showReportDialog(String title, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportMetric('Items Scanned', report['scanned']?.toString() ?? '0'),
              _buildReportMetric('Approved', report['approved']?.toString() ?? '0'),
              if (report['pending'] != null)
                _buildReportMetric('Pending', report['pending'].toString()),
              if (report['returned'] != null)
                _buildReportMetric('Returned', report['returned'].toString()),
              if (report['voided'] != null)
                _buildReportMetric('Voided', report['voided'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _exportReport(String format) async {
    // Show dialog to select export options
    final exportOptions = await _showExportOptionsDialog();
    if (exportOptions == null) return; // User cancelled

    setState(() => _isGenerating = true);
    try {
      // Build query based on options
      var query = supabase
          .from('clothes')
          .select('id, brand, color, type, status, created_at, washer_id, checker_id');

      // Apply date range filter
      if (exportOptions['useDateRange'] == true) {
        final startDate = exportOptions['startDate'] as DateTime;
        final endDate = exportOptions['endDate'] as DateTime;
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        
        query = query
            .gte('created_at', startOfDay.toIso8601String())
            .lte('created_at', endOfDay.toIso8601String());
      }

      // Apply status filter if selected
      if (exportOptions['status'] != null && exportOptions['status'] != 'all') {
        query = query.eq('status', exportOptions['status']);
      }

      final itemsResponse = await query.order('created_at', ascending: false);
      final items = List<Map<String, dynamic>>.from(itemsResponse);

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No data found for the selected criteria.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Generate filename with date range if applicable
      String baseFilename;
      if (exportOptions['useDateRange'] == true) {
        final startDate = exportOptions['startDate'] as DateTime;
        final endDate = exportOptions['endDate'] as DateTime;
        baseFilename = 'report_${startDate.toString().split(' ')[0]}_to_${endDate.toString().split(' ')[0]}';
      } else {
        baseFilename = 'report_all_data_${DateTime.now().toIso8601String().split('T')[0]}';
      }
      
      // Add appropriate extension based on format
      String filename;
      if (format == 'CSV') {
        filename = '$baseFilename.csv';
      } else if (format == 'XLSX') {
        filename = '$baseFilename.xlsx';
      } else if (format == 'PDF') {
        filename = '$baseFilename.pdf';
      } else {
        filename = '$baseFilename.csv';
      }

      if (format == 'CSV') {
        _exportToCSV(items, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV file downloaded successfully! (${items.length} items)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (format == 'XLSX') {
        _exportToXLSX(items, filename);
        // Success message is shown inside _exportToXLSX
      } else if (format == 'PDF') {
        await _exportToPDF(items, filename);
        // Success message is shown inside _exportToPDF
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: ${safeErrorToString(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showExportOptionsDialog() async {
    DateTime? startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime? endDate = DateTime.now();
    bool useDateRange = false; // Default to "All Data"
    String selectedStatus = 'all';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<bool>(
                      title: const Text('All Data'),
                      value: false,
                      groupValue: useDateRange,
                      onChanged: (value) {
                        setDialogState(() {
                          useDateRange = false;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('Date Range'),
                      value: true,
                      groupValue: useDateRange,
                      onChanged: (value) {
                        setDialogState(() {
                          useDateRange = true;
                        });
                      },
                    ),
                    if (useDateRange) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Start Date'),
                        subtitle: Text(startDate != null
                            ? startDate.toString().split(' ')[0]
                            : 'Not selected'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: endDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startDate = picked;
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('End Date'),
                        subtitle: Text(endDate != null
                            ? endDate.toString().split(' ')[0]
                            : 'Not selected'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: startDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              endDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Filter by Status',
                        isDense: true,
                      ),
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'pending_check', child: Text('Pending Check')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'returned', child: Text('Returned')),
                        DropdownMenuItem(value: 'voided', child: Text('Voided')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStatus = value ?? 'all';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (useDateRange && (startDate == null || endDate == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select both start and end dates')),
                      );
                      return;
                    }
                    if (useDateRange && startDate != null && endDate != null) {
                      if (startDate!.isAfter(endDate!)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Start date must be before end date')),
                        );
                        return;
                      }
                    }
                    Navigator.pop(context, {
                      'useDateRange': useDateRange,
                      'startDate': startDate,
                      'endDate': endDate,
                      'status': selectedStatus,
                    });
                  },
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _escapeCsvField(String field) {
    // Escape quotes and wrap in quotes if contains comma, quote, or newline
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  void _exportToCSV(List<Map<String, dynamic>> items, String filename) {
    // Create CSV content with proper escaping
    final csv = StringBuffer();
    csv.writeln('ID,Brand,Color,Type,Status,Created At');
    
    for (var item in items) {
      csv.writeln([
        _escapeCsvField((item['id'] ?? '').toString()),
        _escapeCsvField((item['brand'] ?? '').toString()),
        _escapeCsvField((item['color'] ?? '').toString()),
        _escapeCsvField((item['type'] ?? '').toString()),
        _escapeCsvField((item['status'] ?? '').toString()),
        _escapeCsvField((item['created_at'] ?? '').toString()),
      ].join(','));
    }

    // Download the CSV file
    _downloadFile(filename, csv.toString(), 'text/csv');
  }

  void _exportToXLSX(List<Map<String, dynamic>> items, String filename) {
    try {
      // Create a new Excel file
      final excelFile = excel.Excel.createExcel();
      excelFile.delete('Sheet1'); // Delete default sheet
      final sheet = excelFile['Report'];

      // Add headers
      final headers = ['ID', 'Brand', 'Color', 'Type', 'Status', 'Created At'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = excel.TextCellValue(headers[i]);
        cell.cellStyle = excel.CellStyle(
          bold: true,
          backgroundColorHex: excel.ExcelColor.fromHexString('#E0E0E0'),
        );
      }

      // Add data rows
      for (int row = 0; row < items.length; row++) {
        final item = items[row];
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1)).value = excel.TextCellValue((item['id'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 1)).value = excel.TextCellValue((item['brand'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row + 1)).value = excel.TextCellValue((item['color'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row + 1)).value = excel.TextCellValue((item['type'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row + 1)).value = excel.TextCellValue((item['status'] ?? '').toString());
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row + 1)).value = excel.TextCellValue((item['created_at'] ?? '').toString());
      }

      // Convert to bytes
      final excelBytes = excelFile.encode();
      if (excelBytes != null) {
        _downloadFileBytes(filename, Uint8List.fromList(excelBytes), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('XLSX file downloaded successfully! (${items.length} items)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to generate XLSX file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to XLSX: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF(List<Map<String, dynamic>> items, String filename) async {
    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Laundry Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Brand', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Color', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Created At', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows
                  ...items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['id'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['brand'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['color'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['type'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['status'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text((item['created_at'] ?? '').toString(), style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Items: ${items.length}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ];
          },
        ),
      );

      // Convert to bytes
      final pdfBytes = await pdf.save();
      _downloadFileBytes(filename, Uint8List.fromList(pdfBytes), 'application/pdf');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF file downloaded successfully! (${items.length} items)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to PDF: ${safeErrorToString(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadFile(String filename, String content, String mimeType) {
    // Create a blob and download it using dart:html
    final bytes = utf8.encode(content);
    _downloadFileBytes(filename, bytes, mimeType);
  }

  void _downloadFileBytes(String filename, Uint8List bytes, String mimeType) {
    // Create a blob and download it using dart:html
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports & Analytics',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Report',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectDate,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text('Date: ${_selectedDate.toString().split(' ')[0]}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isGenerating ? null : _generateDailyReport,
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Generate Daily Report'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Report',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('Auto-generated nightly'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isGenerating ? null : _viewMonthlyReports,
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('View Monthly Reports'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export Center',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Create custom reports in CSV, XLSX, or PDF format'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _exportReport('CSV'),
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export CSV'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _exportReport('XLSX'),
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export XLSX'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : () => _exportReport('PDF'),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historical Reports',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Searchable archive of reports by date, customer, or status'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Reports',
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by date, customer, or status...',
                    ),
                    onChanged: (value) {
                      // Implement search functionality if needed
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// System Settings Section