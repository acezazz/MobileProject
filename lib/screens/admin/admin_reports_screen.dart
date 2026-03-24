import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/report_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/report_providers.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(pendingReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Reports')),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(child: Text('No pending reports'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Type: ${report.type.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Reason: ${report.reason}'),
                      if (report.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text('Details: ${report.description}'),
                      ],
                      if (report.type == ReportType.post) ...[
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () =>
                              context.push('/post/${report.reportedId}'),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open Post'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () => _review(
                              context,
                              ref,
                              report,
                              ReportStatus.resolved,
                            ),
                            child: const Text('Resolve'),
                          ),
                          OutlinedButton(
                            onPressed: () => _review(
                              context,
                              ref,
                              report,
                              ReportStatus.dismissed,
                            ),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed: $error')),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    ReportModel report,
    ReportStatus status,
  ) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final ok = await ref
        .read(reviewReportProvider.notifier)
        .review(reportId: report.id, status: status, reviewerId: uid);

    if (ok &&
        status == ReportStatus.resolved &&
        report.type == ReportType.post) {
      try {
        await ref.read(postRepositoryProvider).archivePost(report.reportedId);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report resolved, but archiving post failed. Please retry from Posts Monitoring.',
            ),
          ),
        );
      }
    }

    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(pendingReportsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report ${status.name}')));
      return;
    }

    var message = 'Review action failed.';
    final reviewState = ref.read(reviewReportProvider);
    reviewState.whenOrNull(
      error: (error, _) {
        message = 'Review failed: $error';
      },
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
