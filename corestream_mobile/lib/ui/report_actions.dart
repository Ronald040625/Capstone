import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../data/repository.dart';

Future<void> runReportExport(
  BuildContext context,
  S strings,
  Future<void> Function() export,
) async {
  try {
    await export();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings('report_ready'))),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings('report_error'))),
    );
  }
}

class ReportButtons extends StatelessWidget {
  const ReportButtons({
    super.key,
    required this.strings,
    required this.onExport,
  });

  final S strings;
  final ValueChanged<ReportFormat> onExport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => onExport(ReportFormat.pdf),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(strings('export_pdf')),
        ),
        OutlinedButton.icon(
          onPressed: () => onExport(ReportFormat.xlsx),
          icon: const Icon(Icons.table_view_outlined, size: 18),
          label: Text(strings('export_excel')),
        ),
      ],
    );
  }
}
