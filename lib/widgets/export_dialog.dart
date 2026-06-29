import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

String generateCsv(List<String> headers, List<List<dynamic>> rows) {
  final buf = StringBuffer();
  buf.writeln(headers.map(_csvEscape).join(','));
  for (final row in rows) {
    buf.writeln(row.map((cell) => _csvEscape(cell?.toString() ?? '')).join(','));
  }
  return buf.toString();
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

class ExportAction {
  final String label;
  final IconData icon;
  final String extension;
  final Future<Uint8List> Function() generateData;

  const ExportAction({
    required this.label,
    required this.icon,
    required this.extension,
    required this.generateData,
  });
}

Future<void> showExportDialog(
  BuildContext context, {
  required String title,
  required List<ExportAction> actions,
}) async {
  final action = await showDialog<ExportAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(a.icon, color: Theme.of(ctx).colorScheme.primary),
            title: Text(a.label),
            trailing: Text('.${a.extension}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            onTap: () => Navigator.pop(ctx, a),
          ),
        )).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
      ],
    ),
  );

  if (action == null || !context.mounted) return;

  final scaffold = ScaffoldMessenger.of(context);
  try {
    final bytes = await action.generateData();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final path = p.join(dir.path, 'export_$timestamp.${action.extension}');
    await File(path).writeAsBytes(bytes);
    if (context.mounted) {
      scaffold.showSnackBar(SnackBar(content: Text('Сохранено: $path')));
    }
  } catch (e) {
    if (context.mounted) {
      scaffold.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }
}
