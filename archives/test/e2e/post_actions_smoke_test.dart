import 'package:archives/providers/router_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest route policy allows landing and guards chats', () {
    final landing = resolveAppRedirect(
      isLoggedIn: false,
      isLoadingAuth: false,
      matchedLocation: '/landing',
      uri: Uri.parse('/landing'),
    );

    final chats = resolveAppRedirect(
      isLoggedIn: false,
      isLoadingAuth: false,
      matchedLocation: '/chats',
      uri: Uri.parse('/chats'),
    );

    expect(landing, isNull);
    expect(chats, '/login?from=%2Fchats');
  });
}
