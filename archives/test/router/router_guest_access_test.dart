import 'package:archives/providers/router_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest can access landing but is redirected from private routes', () {
    final landingRedirect = resolveAppRedirect(
      isLoggedIn: false,
      isLoadingAuth: false,
      matchedLocation: '/landing',
      uri: Uri.parse('/landing'),
    );

    final chatsRedirect = resolveAppRedirect(
      isLoggedIn: false,
      isLoadingAuth: false,
      matchedLocation: '/chats',
      uri: Uri.parse('/chats'),
    );

    expect(landingRedirect, isNull);
    expect(chatsRedirect, '/login?from=%2Fchats');
  });
}
