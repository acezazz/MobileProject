class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'An unexpected error occurred']);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  AuthException([this.message = 'Authentication failed']);

  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;
  CacheException([this.message = 'Cache error']);

  @override
  String toString() => message;
}
