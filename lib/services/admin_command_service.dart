import 'package:cloud_functions/cloud_functions.dart';

class AdminCommandException implements Exception {
  final String code;
  final String message;

  const AdminCommandException({required this.code, required this.message});

  @override
  String toString() => 'AdminCommandException(code: $code, message: $message)';
}

typedef CommandInvoker =
    Future<dynamic> Function(String command, Map<String, dynamic> payload);

class AdminCommandService {
  static const String refreshRequiredCode = 'refresh-required';
  final CommandInvoker _invoker;

  AdminCommandService({CommandInvoker? invoker})
    : _invoker = invoker ?? _defaultInvoker;

  static Future<dynamic> _defaultInvoker(
    String command,
    Map<String, dynamic> payload,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(command);
    final result = await callable.call(payload);
    return result.data;
  }

  Future<String> createReport({
    required String reportedId,
    required String type,
    required String reason,
    String? description,
  }) async {
    final data = await _invoke('createReport', {
      'reportedId': reportedId,
      'type': type,
      'reason': reason,
      'description': description,
    });

    final reportId = data['reportId'];
    if (reportId is! String || reportId.trim().isEmpty) {
      throw const AdminCommandException(
        code: 'data-loss',
        message: 'createReport did not return a valid reportId.',
      );
    }
    return reportId;
  }

  Future<void> reviewReport({
    required String reportId,
    required String status,
    String? resolutionNote,
  }) async {
    await _invoke('reviewReport', {
      'reportId': reportId,
      'status': status,
      'resolutionNote': resolutionNote,
    });
  }

  Future<void> suspendUser({
    required String targetUserId,
    required String reason,
  }) async {
    await _invoke('suspendUser', {
      'targetUserId': targetUserId,
      'reason': reason,
    });
  }

  Future<void> unsuspendUser({required String targetUserId}) async {
    await _invoke('unsuspendUser', {'targetUserId': targetUserId});
  }

  Future<void> setUserRole({
    required String targetUserId,
    required String role,
  }) async {
    await _invoke('setUserRole', {'targetUserId': targetUserId, 'role': role});
  }

  Future<Map<String, dynamic>> _invoke(
    String command,
    Map<String, dynamic> payload,
  ) async {
    try {
      final raw = await _invoker(command, payload);
      if (raw == null) return <String, dynamic>{};
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? 'Command failed.';
      final normalizedMessage = message.toLowerCase();
      final isRefreshRequired =
          e.code == 'failed-precondition' &&
          (normalizedMessage.contains('role changed') ||
              normalizedMessage.contains('refresh authentication'));

      throw AdminCommandException(
        code: isRefreshRequired ? refreshRequiredCode : e.code,
        message: isRefreshRequired
            ? 'Your permissions changed. Please sign in again and retry.'
            : message,
      );
    }
  }
}
