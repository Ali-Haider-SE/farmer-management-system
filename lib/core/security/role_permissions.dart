/// Centralized authorization rules for the Farmer Management System.
///
/// UI navigation uses these rules to hide modules a role cannot access.
/// The same helpers are also used by page-opening actions so access cannot
/// accidentally be granted through a stale/invalid menu index.
class RolePermissions {
  RolePermissions._();

  static const String admin = 'Admin';
  static const String farmManager = 'Farm Manager';
  static const String cropManager = 'Rice/Wheat Manager';
  static const String accountant = 'Accountant';

  // Dashboard menu indices:
  // 0 Dashboard, 1 Farm, 2 Rice, 3 Wheat, 4 Parties/Khata,
  // 5 Accounts, 6 Stock, 7 Reports, 8 Settings.
  static const Map<String, Set<int>> _menuAccess = {
    admin: {0, 1, 2, 3, 4, 5, 6, 7, 8},
    farmManager: {0, 1, 6, 7},
    cropManager: {0, 2, 3, 6, 7},
    accountant: {0, 4, 5, 7},
  };

  static Set<int> accessibleMenuIndices(String role) {
    final normalizedRole = role.trim().toLowerCase();

    switch (normalizedRole) {
      case 'admin':
        return Set.unmodifiable(_menuAccess[admin]!);

      case 'farm manager':
        return Set.unmodifiable(_menuAccess[farmManager]!);

      case 'rice/wheat manager':
        return Set.unmodifiable(_menuAccess[cropManager]!);

      case 'accountant':
        return Set.unmodifiable(_menuAccess[accountant]!);

      default:
        // Unknown/invalid roles get dashboard access only.
        // Do NOT fall back to Accountant permissions.
        return const <int>{0};
    }
  }

  static bool canAccessMenu(String role, int index) {
    return accessibleMenuIndices(role).contains(index);
  }

  static bool canManageFarms(String role) => canAccessMenu(role, 1);

  static bool canManageRice(String role) => canAccessMenu(role, 2);

  static bool canManageWheat(String role) => canAccessMenu(role, 3);

  static bool canManageParties(String role) => canAccessMenu(role, 4);

  static bool canManageAccounts(String role) => canAccessMenu(role, 5);

  static bool canManageStock(String role) => canAccessMenu(role, 6);

  static bool canViewReports(String role) => canAccessMenu(role, 7);

  static bool canManageSettings(String role) => canAccessMenu(role, 8);
}
