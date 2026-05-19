/// App-wide constants for CricLocal.

class AppConstants {
  AppConstants._();

  static const String appName = 'CricLocal';
  static const String appTagline = 'Score Cricket. Anywhere.';

  // Database
  static const String dbName = 'cric_local.db';
  static const int dbVersion = 1;

  // Cricket rules
  static const int ballsPerOver = 6;
  static const int maxWickets = 10;

  // Default match settings
  static const int defaultOvers = 20;
  static const int defaultPlayersPerSide = 11;
}
