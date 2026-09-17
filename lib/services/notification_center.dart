import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import 'settings_controller.dart';
import 'storage_service.dart';

/// A real, working notification engine.
///
/// Previously `notificationsEnabled` was a setting that was saved and never
/// read anywhere — no notification was ever actually produced. This class
/// fixes that: it keeps a persisted list of [NotificationModel]s, exposes an
/// unread count for the bell icon in the top bar, and has rule-based
/// generators (`checkLowStock`, `checkKhataDue`) that dashboard/stock/party
/// screens call after loading their data to raise real alerts.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();

  static final NotificationCenter instance = NotificationCenter._();

  static const _storageKey = 'app_notifications';

  final List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications..sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      ));

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    await reload();
  }

  /// Re-reads persisted notifications. Useful after restore/reset operations
  /// where the underlying storage has changed outside this controller.
  Future<void> reload() async {
    final stored = StorageService.instance.getJsonList(_storageKey);
    _notifications
      ..clear()
      ..addAll(stored.map(NotificationModel.fromJson));
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.instance.setJsonList(
      _storageKey,
      _notifications.map((n) => n.toJson()).toList(),
    );
  }

  /// Adds a notification, unless notifications are disabled in Settings or
  /// an unread notification with the same [dedupeKey] already exists (so we
  /// don't spam "Rice stock low" every time the dashboard refreshes).
  Future<void> add({
    required String title,
    required String message,
    String type = 'info',
    String? dedupeKey,
  }) async {
    if (!SettingsController.instance.notificationsEnabled) return;

    if (dedupeKey != null) {
      final exists = _notifications.any(
        (n) => n.id.startsWith(dedupeKey) && !n.isRead,
      );
      if (exists) return;
    }

    final id =
        '${dedupeKey ?? type}_${DateTime.now().millisecondsSinceEpoch}';

    _notifications.add(
      NotificationModel(
        id: id,
        title: title,
        message: message,
        type: type,
        createdAt: DateTime.now(),
      ),
    );

    // Keep the list bounded.
    if (_notifications.length > 200) {
      _notifications.removeRange(0, _notifications.length - 200);
    }

    notifyListeners();
    await _persist();
  }

  Future<void> markRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
    await _persist();
  }

  // =========================================================
  // RULE-BASED SYSTEM ALERTS
  // =========================================================

  /// Call after stock figures are loaded. Raises a low-stock alert when
  /// quantity drops below [threshold] units.
  Future<void> checkLowStock({
    required String label, // e.g. "Rice" or "Wheat"
    required double quantity,
    double threshold = 50,
  }) async {
    if (quantity > threshold) return;
    await add(
      title: 'Low $label Stock',
      message: quantity <= 0
          ? '$label stock is out. Current quantity: 0.'
          : '$label stock is running low: ${quantity.toStringAsFixed(0)} '
                'units left (threshold: ${threshold.toStringAsFixed(0)}).',
      type: 'warning',
      dedupeKey: 'low_stock_$label',
    );
  }

  /// Call after party/khata balances are loaded. Raises a reminder for
  /// parties with an outstanding receivable above [threshold].
  Future<void> checkKhataDue({
    required String partyName,
    required String partyId,
    required double balance, // positive = receivable (they owe you)
    double threshold = 10000,
  }) async {
    if (balance < threshold) return;
    await add(
      title: 'Khata Payment Due',
      message:
          '$partyName has an outstanding balance of '
          '${balance.toStringAsFixed(0)}. Consider following up.',
      type: 'reminder',
      dedupeKey: 'khata_due_$partyId',
    );
  }

  /// Raises a reminder when a receivable has remained outstanding for at
  /// least [days] days. The date should be the oldest relevant khata entry.
  Future<void> checkAgedKhata({
    required String partyName,
    required String partyId,
    required double balance,
    required DateTime? oldestDate,
    int days = 30,
  }) async {
    if (balance <= 0 || oldestDate == null) return;

    final age = DateTime.now().difference(oldestDate).inDays;
    if (age < days) return;

    await add(
      title: 'Old Khata Payment',
      message: '$partyName has Rs. ${balance.toStringAsFixed(0)} outstanding '
          'for about $age days.',
      type: 'warning',
      dedupeKey: 'aged_khata_${partyId}_$days',
    );
  }
}
