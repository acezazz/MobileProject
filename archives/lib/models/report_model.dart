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
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? resolutionNote;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.type,
    required this.reason,
    this.description,
    this.status = ReportStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.resolutionNote,
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
      reviewedBy: map['reviewedBy'],
      reviewedAt: _parseDateTime(map['reviewedAt']),
      resolutionNote: map['resolutionNote'],
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reportedId': reportedId,
      'type': type.name,
      'reason': reason,
      'description': description,
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'resolutionNote': resolutionNote,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
