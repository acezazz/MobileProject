import 'package:archives/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserModel defaults missing role to user', () {
    final model = UserModel.fromMap({
      'uid': 'u1',
      'name': 'Demo',
      'username': 'demo',
      'email': 'demo@example.com',
      'createdAt': DateTime.now(),
    }, 'u1');

    expect(model.role, 'user');
  });

  test('UserModel keeps explicit admin role from map', () {
    final model = UserModel.fromMap({
      'uid': 'u2',
      'name': 'Admin',
      'username': 'admin',
      'email': 'admin@example.com',
      'createdAt': DateTime.now(),
      'role': 'admin',
    }, 'u2');

    expect(model.role, 'admin');
  });
}
