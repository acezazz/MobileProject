import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../core/constants/firestore_constants.dart';
import '../models/report_model.dart';

class ReportRepository {
  final FirebaseFirestore _firestore;

  ReportRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _reportsRef =>
      _firestore.collection(FirestoreConstants.reportsCollection);

  Future<String> submitReport({
    required String reporterId,
    required String reportedId,
    required ReportType type,
    required String reason,
    String? description,
  }) async {
    final reportRef = _reportsRef.doc();
    final payload = {
      'reporterId': reporterId,
      'reportedId': reportedId,
      'type': type.name,
      'reason': reason,
      'description': description,
      'status': ReportStatus.pending.name,
      'reviewedBy': null,
      'reviewedAt': null,
      'resolutionNote': null,
      'createdAt': Timestamp.now(),
    };

    try {
      await reportRef.set(payload);
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await reportRef.set(payload);
    }
    return reportRef.id;
  }

  Future<List<ReportModel>> getUserReports(String userId) async {
    final snapshot = await _reportsRef
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<List<ReportModel>> getPendingReports() async {
    final snapshot = await _reportsRef
        .where('status', isEqualTo: ReportStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<void> updateReportStatus(String reportId, ReportStatus status) async {
    throw UnsupportedError(
      'Direct report status updates are disabled. Use reviewReport.',
    );
  }

  Future<List<ReportModel>> getReportsByStatus(ReportStatus status) async {
    final snapshot = await _reportsRef
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<void> reviewReport({
    required String reportId,
    required ReportStatus status,
    required String reviewerId,
    String? resolutionNote,
  }) async {
    await _reportsRef.doc(reportId).update({
      'status': status.name,
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'resolutionNote': resolutionNote,
    });
  }
}
