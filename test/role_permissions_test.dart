import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_management/core/security/role_permissions.dart';

void main() {
  group('RolePermissions', () {
    test('Admin can access every module', () {
      expect(
        RolePermissions.accessibleMenuIndices(RolePermissions.admin),
        {0, 1, 2, 3, 4, 5, 6, 7, 8},
      );
    });

    test('Farm Manager only gets farm, stock and reports', () {
      expect(
        RolePermissions.accessibleMenuIndices(RolePermissions.farmManager),
        {0, 1, 6, 7},
      );
      expect(RolePermissions.canManageAccounts(RolePermissions.farmManager), isFalse);
      expect(RolePermissions.canManageFarms(RolePermissions.farmManager), isTrue);
    });

    test('Rice/Wheat Manager only gets crop, stock and reports', () {
      expect(
        RolePermissions.accessibleMenuIndices(RolePermissions.cropManager),
        {0, 2, 3, 6, 7},
      );
      expect(RolePermissions.canManageRice(RolePermissions.cropManager), isTrue);
      expect(RolePermissions.canManageWheat(RolePermissions.cropManager), isTrue);
      expect(RolePermissions.canManageParties(RolePermissions.cropManager), isFalse);
    });

    test('Accountant only gets parties, accounts and reports', () {
      expect(
        RolePermissions.accessibleMenuIndices(RolePermissions.accountant),
        {0, 4, 5, 7},
      );
      expect(RolePermissions.canManageParties(RolePermissions.accountant), isTrue);
      expect(RolePermissions.canManageAccounts(RolePermissions.accountant), isTrue);
      expect(RolePermissions.canManageFarms(RolePermissions.accountant), isFalse);
    });
  });
}
