import 'package:logger/logger.dart';

final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
  ),
);

class AppLogger {
  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warn(String message) => _logger.w(message);
  static void error(String message, [Object? error, StackTrace? stack]) =>
      _logger.e(message, error: error, stackTrace: stack);
}
