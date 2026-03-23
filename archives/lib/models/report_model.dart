import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { post, user, comment, message }

enum ReportStatus { pending, reviewed, resolved, dismissed }

class ReportModel {
  final String id;
  final String reporterId;
  final String reportedId;
  final ReportType type;
  final String reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.type,
    required this.reason,
    this.description,
    this.status = ReportStatus.pending,
    required this.createdAt,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReportModel(
      id: docId,
      reporterId: map['reporterId'] ?? '',
      reportedId: map['reportedId'] ?? '',
      type: ReportType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ReportType.post,
      ),
      reason: map['reason'] ?? '',
      description: map['description'],
      status: ReportStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReportStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reportedId': reportedId,
      'type': type.name,
      'reason': reason,
      'description': description,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
