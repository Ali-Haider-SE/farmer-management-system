import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_management/app.dart';
import 'package:farmer_management/services/storage_service.dart';
import 'package:farmer_management/services/database_service.dart';
import 'package:farmer_management/services/settings_controller.dart';
import 'package:farmer_management/services/notification_center.dart';

void main() {
  setUp(() async {
    await StorageService.instance.init();
    await DatabaseService.instance.init();
    await SettingsController.instance.load();
    await NotificationCenter.instance.load();
  });

  testWidgets('Farmer Management login screen loads', (WidgetTester tester) async {
    await StorageService.instance.remove('current_user');
    await tester.pumpWidget(const FarmerManagementApp());
    await tester.pumpAndSettle();

    expect(find.text('Farmer Management'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  test('database schema is initialized', () async {
    expect(DatabaseService.instance.isInitialized, isTrue);
    expect(
      StorageService.instance.getInt(DatabaseService.schemaVersionKey),
      DatabaseService.schemaVersion,
    );
  });
}
