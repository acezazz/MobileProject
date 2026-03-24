import 'package:archives/providers/router_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest is redirected to login for admin routes', () {
    final redirect = resolveAppRedirect(
      isLoggedIn: false,
      isLoadingAuth: false,
      matchedLocation: '/admin',
      uri: Uri.parse('/admin'),
      currentUserRole: null,
    );

    expect(redirect, '/login?from=%2Fadmin');
  });

  test('logged-in non-admin is redirected from admin routes', () {
    final redirect = resolveAppRedirect(
      isLoggedIn: true,
      isLoadingAuth: false,
      matchedLocation: '/admin/reports',
      uri: Uri.parse('/admin/reports'),
      currentUserRole: 'user',
    );

    expect(redirect, '/');
  });

  test('admin can access admin routes', () {
    final redirect = resolveAppRedirect(
      isLoggedIn: true,
      isLoadingAuth: false,
      matchedLocation: '/admin/reports',
      uri: Uri.parse('/admin/reports'),
      currentUserRole: 'admin',
    );

    expect(redirect, isNull);
  });

  test('logged-in admin is redirected away from user routes', () {
    final redirect = resolveAppRedirect(
      isLoggedIn: true,
      isLoadingAuth: false,
      matchedLocation: '/settings',
      uri: Uri.parse('/settings'),
      currentUserRole: 'admin',
    );

    expect(redirect, '/admin');
  });

  test('logged-in admin stays on admin root route', () {
    final redirect = resolveAppRedirect(
      isLoggedIn: true,
      isLoadingAuth: false,
      matchedLocation: '/admin',
      uri: Uri.parse('/admin'),
      currentUserRole: 'superAdmin',
    );

    expect(redirect, isNull);
  });
}
