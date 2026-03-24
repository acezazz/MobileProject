import 'package:archives/services/admin_command_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createReport returns reportId from command response', () async {
    String? commandName;
    Map<String, dynamic>? capturedPayload;

    final service = AdminCommandService(
      invoker: (command, payload) async {
        commandName = command;
        capturedPayload = payload;
        return {'reportId': 'r-123'};
      },
    );

    final reportId = await service.createReport(
      reportedId: 'target-1',
      type: 'user',
      reason: 'spam',
      description: 'details',
    );

    expect(reportId, 'r-123');
    expect(commandName, 'createReport');
    expect(capturedPayload?['reportedId'], 'target-1');
    expect(capturedPayload?['type'], 'user');
    expect(capturedPayload?['reason'], 'spam');
  });

  test('createReport throws data-loss when reportId is missing', () async {
    final service = AdminCommandService(
      invoker: (command, payload) async => {'ok': true},
    );

    expect(
      () =>
          service.createReport(reportedId: 'u2', type: 'user', reason: 'spam'),
      throwsA(
        isA<AdminCommandException>().having((e) => e.code, 'code', 'data-loss'),
      ),
    );
  });

  test('maps FirebaseFunctionsException into AdminCommandException', () async {
    final service = AdminCommandService(
      invoker: (command, payload) async {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'No access',
        );
      },
    );

    expect(
      () => service.reviewReport(reportId: 'r1', status: 'resolved'),
      throwsA(
        isA<AdminCommandException>()
            .having((e) => e.code, 'code', 'permission-denied')
            .having((e) => e.message, 'message', 'No access'),
      ),
    );
  });

  test(
    'maps role mismatch failed-precondition into refresh-required',
    () async {
      final service = AdminCommandService(
        invoker: (command, payload) async {
          throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Role changed. Refresh authentication and retry.',
          );
        },
      );

      expect(
        () => service.suspendUser(targetUserId: 'u2', reason: 'abuse'),
        throwsA(
          isA<AdminCommandException>()
              .having(
                (e) => e.code,
                'code',
                AdminCommandService.refreshRequiredCode,
              )
              .having(
                (e) => e.message,
                'message',
                'Your permissions changed. Please sign in again and retry.',
              ),
        ),
      );
    },
  );
}
