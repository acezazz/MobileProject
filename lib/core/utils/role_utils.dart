import '../constants/role_constants.dart';

bool isAdminOrHigher(String? role) {
  return role == RoleConstants.admin || role == RoleConstants.superAdmin;
}
