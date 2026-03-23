class AppConstants {
  AppConstants._();

  static const String appName = 'Archives';
  static const String appVersion = '1.0.0';

  // Default profile photo placeholder URL
  static const String defaultProfilePhoto =
      'https://ui-avatars.com/api/?background=1a1a2e&color=fff&name=User';

  // Pagination
  static const int postsPerPage = 20;
  static const int messagesPerPage = 50;
  static const int usersPerPage = 30;

  // Validation limits
  static const int maxPostLength = 500;
  static const int maxBioLength = 150;
  static const int maxUsernameLength = 30;
  static const int minUsernameLength = 3;
  static const int minPasswordLength = 6;
}
