# Farmer Management System — Finalization Report

## Architecture
- Flutter remains the client application.
- PostgreSQL/API is now the authoritative source for business data.
- Repositories for Rice, Wheat, Stock, Parties/Khata, Accounts, Reports, Farms and Dashboard calculations are API-first.
- SharedPreferences is retained for settings/session-compatible cache and local backup functionality only.
- API base URL is centralized in `lib/services/api_service.dart` and configured with `--dart-define=API_BASE_URL=...`.

## Authentication / Security
- AuthRepository no longer hardcodes its own API URL.
- JWT tokens use `flutter_secure_storage`.
- ApiService automatically sends the bearer token.
- `/api/auth/me` is used for session restoration.
- Token expiry/401 clears authentication.
- Server-side role authorization is applied to business route families.
- Password change endpoint added with authorization.
- Login rate limiting added without an extra dependency.
- CORS is configurable; production rejects wildcard CORS.
- Security response headers are added.
- Database credentials and the previous JWT secret were removed from the distributable project.
- `.env.example` documents required configuration.

## Business Modules
- Farmers: API CRUD with server-side validation.
- Farms: API CRUD plus persistent farm activities for production/income/expense.
- Parties/Khata: API CRUD, UUID handling, opening-balance recalculation and running-balance recalculation.
- Rice: API CRUD, server-side financial validation and Khata synchronization.
- Wheat: API CRUD, server-side financial validation and Khata synchronization.
- Stock: API persistence, movements, quantity guards and movement deletion support.
- Accounts: API CRUD, account transactions, balance recalculation and transaction update/delete.
- Reports: switched from local business data to API/database data.
- Dashboard: switched business calculations from local storage to API/database data.
- Backup/restore: added admin-only PostgreSQL-backed JSON snapshot/restore endpoints. Password hashes/user accounts are intentionally excluded from business restore snapshots.

## Database
- Migration runner now applies ordered migration files instead of only migration 001.
- Migration 002 adds integrity constraints and indexes.
- Migration 003 adds persistent `farm_activities`.
- Existing valid tables are preserved; no destructive migration was used.
- Financial values have non-negative database constraints where appropriate.

## Localization / RTL
- Proper Flutter `LocalizationsDelegate` infrastructure added for English and Urdu.
- `MaterialApp.locale` follows the persisted language setting.
- Flutter global material/widgets/cupertino localizations are registered.
- Urdu locale enables RTL through Flutter localization.
- Language selection remains persisted through the settings controller.

## Testing performed
### Passed
- Node syntax check for all backend JavaScript files.
- Backend `npm test`: 3/3 tests passed.
  - Public health endpoint.
  - Unauthorized business API rejection.
  - Protected database health endpoint.
- Backend server startup was verified.
- `/api/health` returned success.
- Protected business endpoints returned HTTP 401 without a token.
- `/api/health/db` returned HTTP 401 without a token.
- API route audit confirmed frontend-used route families have corresponding backend routes.

### Not executable in this environment
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build web`
- `flutter build apk`
- PostgreSQL migration/CRUD integration tests

Reason: this execution environment does not contain the Flutter/Dart SDK, and no PostgreSQL service/database was available for the uploaded project's configured database connection. These were therefore not falsely marked as passed.

## Important setup
1. Copy `backend/.env.example` to `backend/.env`.
2. Set a strong unique `JWT_SECRET`.
3. Set the real `DATABASE_URL`.
4. Configure `CORS_ORIGINS` for the Flutter web origin in production.
5. Run `npm install` if `node_modules` is not available.
6. Run `npm run migrate`.
7. Start with `npm start`.
8. Run Flutter with the appropriate `--dart-define=API_BASE_URL=...`.

## Remaining verification
The only material verification gap is Flutter compilation/runtime testing and live PostgreSQL CRUD testing because those runtimes/services were unavailable here. The project source was updated so those checks can be executed on the developer machine with the required SDK and PostgreSQL service.
