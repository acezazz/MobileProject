import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../models/report_model.dart';

class ReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _reportsRef =>
      _firestore.collection(FirestoreConstants.reportsCollection);

  Future<String> submitReport({
    required String reporterId,
    required String reportedId,
    required ReportType type,
    required String reason,
    String? description,
  }) async {
    final report = ReportModel(
      id: '',
      reporterId: reporterId,
      reportedId: reportedId,
      type: type,
      reason: reason,
      description: description,
      status: ReportStatus.pending,
      createdAt: DateTime.now(),
    );
    final docRef = await _reportsRef.add(report.toMap());
    return docRef.id;
  }

  Future<List<ReportModel>> getUserReports(String userId) async {
    final snapshot = await _reportsRef
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<List<ReportModel>> getPendingReports() async {
    final snapshot = await _reportsRef
        .where('status', isEqualTo: ReportStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> updateReportStatus(String reportId, ReportStatus status) async {
    await _reportsRef.doc(reportId).update({'status': status.name});
  }
}
