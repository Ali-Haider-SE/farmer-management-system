import 'package:flutter/material.dart';

import 'app.dart';
export 'app.dart';

import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'services/settings_controller.dart';
import 'services/notification_center.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();
  await DatabaseService.instance.init();
  await SettingsController.instance.load();
  await NotificationCenter.instance.load();

  runApp(const FarmerManagementApp());
}
