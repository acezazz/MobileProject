import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/report_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/report_providers.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final ReportType type;
  final String reportedId;

  const ReportScreen({super.key, required this.type, required this.reportedId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();

  static const _reasons = [
    'Spam',
    'Harassment or bullying',
    'Hate speech',
    'Violence',
    'Nudity or sexual content',
    'False information',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a reason')));
      return;
    }

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    final success = await ref
        .read(submitReportProvider.notifier)
        .submit(
          reporterId: currentUser.uid,
          reportedId: widget.reportedId,
          type: widget.type,
          reason: _selectedReason!,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(submitReportProvider);
    final isLoading = reportState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this ${widget.type.name}?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your report is anonymous. We will review this within 24 hours.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Reason selection
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (val) => setState(() => _selectedReason = val),
              child: Column(
                children: List.generate(_reasons.length, (index) {
                  final reason = _reasons[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: RadioListTile<String>(
                      value: reason,
                      title: Text(
                        reason,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      activeColor: AppColors.secondaryAccent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Optional description
            CustomTextField(
              controller: _descriptionController,
              hintText: 'Additional details (optional)',
              maxLines: 4,
              fillColor: AppColors.accentBeige,
              textColor: AppColors.inkDark,
              hintColor: AppColors.inkDark,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Submit Report',
              isLoading: isLoading,
              onPressed: _handleSubmit,
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.inkDark,
            ),
          ],
        ),
      ),
    );
  }
}
