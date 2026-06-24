CibusSanus patch bundle

Replace your matching files under lib/ with the versions in this archive.

Run examples:
Desktop:
  flutter run --dart-define=DB_HOST=127.0.0.1

Android emulator:
  flutter run --dart-define=DB_HOST=10.0.2.2

Physical Android device:
  flutter run --dart-define=DB_HOST=<your PC LAN IP>

Optional defines:
  --dart-define=DB_USER=postgres
  --dart-define=DB_PASSWORD=080918
  --dart-define=DB_NAME=restaurant_db
  --dart-define=DB_PORT=5432

The project assumes existing tables:
  categories, dishes, orders, order_items
