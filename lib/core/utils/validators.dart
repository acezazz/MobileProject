class Validators {
  Validators._();

  static final DateTime _minimumAllowedBirthDate = DateTime(
    DateTime.now().year - 13,
    DateTime.now().month,
    DateTime.now().day,
  );

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]+$');
    if (!usernameRegex.hasMatch(value.trim())) {
      return 'Only letters, numbers, dots, and underscores';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? birthDate(DateTime? value) {
    if (value == null) return 'Birthdate is required';
    if (value.isAfter(_minimumAllowedBirthDate)) {
      return 'You must be at least 13 years old';
    }
    return null;
  }

  static String? gender(String? value) {
    if (value == null || value.trim().isEmpty) return 'Gender is required';
    return null;
  }

  static String? notEmpty(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? imageUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional field
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return 'Enter a valid URL starting with http:// or https://';
    }
    return null;
  }
}
