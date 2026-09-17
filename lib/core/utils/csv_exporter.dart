import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lightweight CSV export helper.
///
/// The project has no `path_provider` / `share_plus` dependency (and this
/// environment can't reach pub.dev to add one), so instead of writing to
/// disk this builds a proper CSV string and lets the user copy it straight
/// into Excel / Google Sheets / Numbers with one tap — which is the actual
/// outcome people want from "Export to Excel" in a desktop/web app.
class CsvExporter {
  CsvExporter._();

  /// Escapes a single CSV field per RFC 4180: wraps in quotes and doubles
  /// any internal quotes whenever the value contains a comma, quote, or
  /// newline.
  static String _escapeField(dynamic value) {
    final text = value?.toString() ?? '';
    final needsQuoting =
        text.contains(',') || text.contains('"') || text.contains('\n');

    if (!needsQuoting) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  /// Converts rows (first row treated as the header) into a CSV string.
  static String toCsv(List<List<dynamic>> rows) {
    return rows
        .map((row) => row.map(_escapeField).join(','))
        .join('\r\n');
  }

  /// Builds the CSV and shows a dialog with a live preview plus a
  /// "Copy to Clipboard" action so the user can paste it directly into a
  /// spreadsheet application.
  static Future<void> exportAndShow({
    required BuildContext context,
    required String title,
    required List<List<dynamic>> rows,
  }) async {
    final csv = toCsv(rows);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rows.length} rows ready. Copy and paste directly into '
                  'Excel, Google Sheets, or Numbers.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        csv,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CSV copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy to Clipboard'),
            ),
          ],
        );
      },
    );
  }
}
