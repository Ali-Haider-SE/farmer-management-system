import '../models/account_model.dart';
import '../models/crop_model.dart';
import '../models/farm_model.dart';
import '../models/farmer_model.dart';
import '../models/khata_model.dart';
import '../models/notification_model.dart';
import '../models/party_model.dart';
import '../models/payment_model.dart';
import '../models/rice_transaction_model.dart';
import '../models/stock_model.dart';
import '../models/user_model.dart';
import '../models/wheat_transaction_model.dart';
import 'storage_service.dart';

/// Application data layer over the SQLite-backed StorageService.
///
/// Collections keep their existing JSON schemas so the UI/repositories remain
/// compatible while persistence is now handled by a real local SQLite file.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const String usersKey = 'users';
  static const String farmersKey = 'farmers';
  static const String farmsKey = 'farms_data';
  static const String cropsKey = 'crops';
  static const String riceKey = 'rice_transactions';
  static const String wheatKey = 'wheat_transactions';
  static const String partiesKey = 'parties_data';
  static const String khataKey = 'khata_entries';
  static const String accountsKey = 'accounts';
  static const String stockKey = 'stock';
  static const String paymentsKey = 'payments';
  static const String notificationsKey = 'app_notifications';

  static const int schemaVersion = 2;
  static const String schemaVersionKey = 'database_schema_version';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // StorageService owns the SQLite connection and legacy migration.
    await StorageService.instance.init();

    final storage = StorageService.instance;
    final previousVersion = storage.getInt(schemaVersionKey) ?? 1;
    if (previousVersion < schemaVersion) {
      await _migrate(previousVersion, schemaVersion);
    }
    await storage.setInt(schemaVersionKey, schemaVersion);
    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;

  /// Lightweight schema migration for the local persistence layer. The app
  /// deliberately keeps the existing JSON record format so old installations
  /// can be upgraded without losing user data.
  Future<void> _migrate(int from, int to) async {
    if (from < 2 && to >= 2) {
      final storage = StorageService.instance;
      // Older builds used accounts_data as the screen-level transaction key.
      // Keep it intact and mirror it into the canonical accounts_transactions
      // key only when the newer key does not already exist.
      if (!storage.containsKey('accounts_transactions') &&
          storage.containsKey('accounts_data')) {
        final raw = storage.getString('accounts_data');
        if (raw != null) {
          await storage.setString('accounts_transactions', raw);
        }
      }
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'DatabaseService has not been initialized. '
        'Call DatabaseService.instance.init() first.',
      );
    }
  }

  Future<void> close() async {
    _isInitialized = false;
  }

  Future<List<UserModel>> getUsers() async {
    _ensureInitialized();
    return _read(usersKey, UserModel.fromJson);
  }

  Future<void> saveUsers(List<UserModel> users) async {
    await _write(usersKey, users.map((e) => e.toJson()).toList());
  }

  Future<List<FarmerModel>> getFarmers() async {
    _ensureInitialized();
    return _read(farmersKey, FarmerModel.fromJson);
  }

  Future<void> saveFarmers(List<FarmerModel> farmers) async {
    await _write(farmersKey, farmers.map((e) => e.toJson()).toList());
  }

  Future<List<FarmModel>> getFarms() async {
    _ensureInitialized();
    return _read(farmsKey, FarmModel.fromJson);
  }

  Future<void> saveFarms(List<FarmModel> farms) async {
    await _write(farmsKey, farms.map((e) => e.toJson()).toList());
  }

  Future<List<CropModel>> getCrops() async {
    _ensureInitialized();
    return _read(cropsKey, CropModel.fromJson);
  }

  Future<void> saveCrops(List<CropModel> crops) async {
    await _write(cropsKey, crops.map((e) => e.toJson()).toList());
  }

  Future<List<RiceTransactionModel>> getRiceTransactions() async {
    _ensureInitialized();
    return _read(riceKey, RiceTransactionModel.fromJson);
  }

  Future<void> saveRiceTransactions(
    List<RiceTransactionModel> transactions,
  ) async {
    await _write(riceKey, transactions.map((e) => e.toJson()).toList());
  }

  Future<List<WheatTransactionModel>> getWheatTransactions() async {
    _ensureInitialized();
    return _read(wheatKey, WheatTransactionModel.fromJson);
  }

  Future<void> saveWheatTransactions(
    List<WheatTransactionModel> transactions,
  ) async {
    await _write(wheatKey, transactions.map((e) => e.toJson()).toList());
  }

  Future<List<PartyModel>> getParties() async {
    _ensureInitialized();
    return _read(partiesKey, PartyModel.fromJson);
  }

  Future<void> saveParties(List<PartyModel> parties) async {
    await _write(partiesKey, parties.map((e) => e.toJson()).toList());
  }

  Future<List<KhataModel>> getKhataEntries() async {
    _ensureInitialized();
    return _read(khataKey, KhataModel.fromJson);
  }

  Future<void> saveKhataEntries(List<KhataModel> entries) async {
    await _write(khataKey, entries.map((e) => e.toJson()).toList());
  }

  Future<List<AccountModel>> getAccounts() async {
    _ensureInitialized();
    return _read(accountsKey, AccountModel.fromJson);
  }

  Future<void> saveAccounts(List<AccountModel> accounts) async {
    await _write(accountsKey, accounts.map((e) => e.toJson()).toList());
  }

  Future<List<StockModel>> getStock() async {
    _ensureInitialized();
    return _read(stockKey, StockModel.fromJson);
  }

  Future<void> saveStock(List<StockModel> stock) async {
    await _write(stockKey, stock.map((e) => e.toJson()).toList());
  }

  Future<List<PaymentModel>> getPayments() async {
    _ensureInitialized();
    return _read(paymentsKey, PaymentModel.fromJson);
  }

  Future<void> savePayments(List<PaymentModel> payments) async {
    await _write(paymentsKey, payments.map((e) => e.toJson()).toList());
  }

  Future<List<NotificationModel>> getNotifications() async {
    _ensureInitialized();
    return _read(notificationsKey, NotificationModel.fromJson);
  }

  Future<void> saveNotifications(
    List<NotificationModel> notifications,
  ) async {
    await _write(
      notificationsKey,
      notifications.map((e) => e.toJson()).toList(),
    );
  }

  List<T> _read<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return StorageService.instance
        .getJsonList(key)
        .map(fromJson)
        .toList();
  }

  Future<void> _write(
    String key,
    List<Map<String, dynamic>> values,
  ) async {
    _ensureInitialized();
    await StorageService.instance.setJsonList(key, values);
  }
}
