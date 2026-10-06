# Farmer Management System — Local VS Code Setup

This archive contains the source project for the Farmer Management System: Flutter frontend + Node.js/Express backend + PostgreSQL.

## 1. Requirements

- Flutter SDK compatible with Dart 3.12.2
- Node.js 22 LTS or compatible Node.js
- PostgreSQL 14+
- VS Code

## 2. Backend

Open a terminal in `backend`:

```powershell
npm ci
Copy-Item .env.example .env
```

Edit `.env` and set a real PostgreSQL password and a long random `JWT_SECRET`.

Create the PostgreSQL database/user as appropriate for your machine, then run:

```powershell
npm run migrate
npm start
```

The API runs on `http://localhost:5000`.

Health check:

```powershell
Invoke-RestMethod http://localhost:5000/api/health | ConvertTo-Json -Depth 10
```

## 3. Flutter frontend

From the project root:

```powershell
flutter pub get
flutter run -d chrome
```

The default API URL is:

`http://localhost:5000/api`

You can override it at build/run time with:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
```

## 4. Important

Do NOT commit `.env`. The supplied archive intentionally excludes the real backend `.env` because it can contain database credentials/secrets. Use `backend/.env.example` to create your local `.env`.

Generated directories such as `.dart_tool`, `build`, and `node_modules` are intentionally excluded. They are recreated with `flutter pub get`, Flutter build/run commands, and `npm ci`.


## API configuration

The Flutter app has one API base URL source: `API_BASE_URL` in `ApiService`.
Examples:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000/api
flutter build web --dart-define=API_BASE_URL=https://your-api.example.com/api
```

Do not put database credentials or JWT secrets in Flutter build variables.
JWT tokens are stored with `flutter_secure_storage`.
