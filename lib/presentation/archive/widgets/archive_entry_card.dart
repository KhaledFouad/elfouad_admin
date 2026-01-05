import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/History/utils/sale_utils.dart';
import 'package:elfouad_admin/presentation/archive/models/archive_entry.dart';
import 'package:elfouad_admin/presentation/archive/utils/archive_utils.dart';
import 'package:flutter/material.dart';

class ArchiveEntryCard extends StatelessWidget {
  const ArchiveEntryCard({
    super.key,
    required this.entry,
    required this.isRestoring,
    required this.onRestore,
  });

  final ArchiveEntry entry;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final title = entryTitle(entry);
    final kind = kindLabel(entry.kind);
    final when = formatDateTime(entry.archivedAt);
    final reason = entry.reason;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          '$kind - $when${reason == null || reason.isEmpty ? '' : ' - ${AppStrings.archiveReasonLabel}: $reason'}',
        ),
        trailing: TextButton.icon(
          onPressed: isRestoring ? null : onRestore,
          icon: const Icon(Icons.restore),
          label: const Text(AppStrings.actionRestore),
        ),
      ),
    );
  }
}
