class DbConfig {
  DbConfig._();

  /// For desktop:
  /// flutter run --dart-define=DB_HOST=127.0.0.1
  ///
  /// For Android emulator:
  /// flutter run --dart-define=DB_HOST=10.0.2.2
  ///
  /// For a real phone:
  /// use your PC LAN IP, e.g. 192.168.1.10
  static const String host = String.fromEnvironment(
    'DB_HOST',
    defaultValue: '127.0.0.1',
  );

  static const String port = String.fromEnvironment(
    'DB_PORT',
    defaultValue: '5432',
  );

  static const String database = String.fromEnvironment(
    'DB_NAME',
    defaultValue: 'restaurant_db',
  );

  static const String username = String.fromEnvironment(
    'DB_USER',
    defaultValue: 'postgres',
  );

  static const String password = String.fromEnvironment(
    'DB_PASSWORD',
    defaultValue: '080918',
  );

  static const String sslMode = String.fromEnvironment(
    'DB_SSLMODE',
    defaultValue: 'disable',
  );

  static String get connectionUrl =>
      'postgresql://$username:$password@$host:$port/$database?sslmode=$sslMode';
}
