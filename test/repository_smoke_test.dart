import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_management/repositories/auth_repository.dart';

void main() {
  test('default admin can authenticate', () async {
    final repository = AuthRepository();

    final admin = await repository.authenticate(
      username: 'admin',
      password: 'admin123',
      role: 'Admin',
    );

    expect(admin, isNotNull);
    expect(admin!.role, 'Admin');
  });

  test('invalid credentials are rejected', () async {
    final repository = AuthRepository();

    final result = await repository.authenticate(
      username: 'admin',
      password: 'wrong-password',
      role: 'Admin',
    );

    expect(result, isNull);
  });
}
