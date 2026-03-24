import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';
import '../repositories/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

// Submit report notifier
final submitReportProvider =
    StateNotifierProvider<SubmitReportNotifier, AsyncValue<void>>((ref) {
      return SubmitReportNotifier(ref.read(reportRepositoryProvider));
    });

final pendingReportsProvider = FutureProvider<List<ReportModel>>((ref) {
  return ref.read(reportRepositoryProvider).getPendingReports();
});

final reviewReportProvider =
    StateNotifierProvider<ReviewReportNotifier, AsyncValue<void>>((ref) {
      return ReviewReportNotifier(ref.read(reportRepositoryProvider));
    });

class SubmitReportNotifier extends StateNotifier<AsyncValue<void>> {
  final ReportRepository _repo;

  SubmitReportNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<bool> submit({
    required String reporterId,
    required String reportedId,
    required ReportType type,
    required String reason,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.submitReport(
        reporterId: reporterId,
        reportedId: reportedId,
        type: type,
        reason: reason,
        description: description,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

class ReviewReportNotifier extends StateNotifier<AsyncValue<void>> {
  final ReportRepository _repo;

  ReviewReportNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<bool> review({
    required String reportId,
    required ReportStatus status,
    required String reviewerId,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.reviewReport(
        reportId: reportId,
        status: status,
        reviewerId: reviewerId,
        resolutionNote: note,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
