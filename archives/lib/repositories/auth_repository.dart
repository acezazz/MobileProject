import 'package:firebase_auth/firebase_auth.dart';
import '../core/errors/exceptions.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class AuthRepository {
  final AuthService _authService;
  final UserService _userService;

  AuthRepository({AuthService? authService, UserService? userService})
    : _authService = authService ?? AuthService(),
      _userService = userService ?? UserService();

  Stream<User?> get authStateChanges => _authService.authStateChanges;
  User? get currentUser => _authService.currentUser;

  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
    required DateTime birthDate,
    required String gender,
  }) async {
    // Create Firebase Auth account first (so user is authenticated for Firestore rules)
    final credential = await _authService.registerWithEmail(
      email: email,
      password: password,
    );

    try {
      // Now check username availability (user is authenticated at this point)
      final isAvailable = await _userService.isUsernameAvailable(username);
      if (!isAvailable) {
        // Delete the auth account since username is taken
        await credential.user?.delete();
        throw AuthException('This username is already taken');
      }

      // Create Firestore user profile
      final user = UserModel(
        uid: credential.user!.uid,
        name: username,
        username: username.toLowerCase(),
        email: email,
        birthDate: birthDate,
        gender: gender,
        createdAt: DateTime.now(),
      );
      await _userService.createUserProfile(user);

      return user;
    } catch (e) {
      // If Firestore fails after auth creation, clean up the auth account
      if (e is! AuthException) {
        await credential.user?.delete();
      }
      rethrow;
    }
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.loginWithEmail(
      email: email,
      password: password,
    );
    return _userService.getUserById(credential.user!.uid);
  }

  Future<void> logout() async {
    await _authService.logout();
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  Future<UserModel?> getCurrentUserProfile() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    return _userService.getUserById(user.uid);
  }
}
