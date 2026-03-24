import 'package:archives/models/report_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ReportModel parses Firestore Timestamp values', () {
    final now = DateTime.utc(2026, 3, 24, 0, 0, 0);
    final model = ReportModel.fromMap({
      'reporterId': 'u1',
      'reportedId': 'u2',
      'type': 'user',
      'reason': 'spam',
      'status': 'pending',
      'createdAt': Timestamp.fromDate(now),
      'reviewedAt': Timestamp.fromDate(now),
    }, 'r1');

    expect(model.createdAt.toUtc(), now);
    expect(model.reviewedAt?.toUtc(), now);
  });

  test('ReportModel parses ISO string timestamps without throwing', () {
    final model = ReportModel.fromMap({
      'reporterId': 'u1',
      'reportedId': 'u2',
      'type': 'user',
      'reason': 'spam',
      'status': 'reviewed',
      'createdAt': '2026-03-24T00:00:00.000Z',
      'reviewedAt': '2026-03-24T00:01:00.000Z',
    }, 'r2');

    expect(model.createdAt.toIso8601String(), '2026-03-24T00:00:00.000Z');
    expect(model.reviewedAt?.toIso8601String(), '2026-03-24T00:01:00.000Z');
  });
}
