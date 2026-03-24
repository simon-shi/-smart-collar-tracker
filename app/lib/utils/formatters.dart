import 'package:intl/intl.dart';

class Formatters {
  static final _dateFormatter = DateFormat('MMM d, yyyy');
  static final _timeFormatter = DateFormat('h:mm a');
  static final _dateTimeFormatter = DateFormat('MMM d, h:mm a');
  static final _shortDateFormatter = DateFormat('MM/dd');

  static String date(DateTime dt) => _dateFormatter.format(dt);
  static String time(DateTime dt) => _timeFormatter.format(dt);
  static String dateTime(DateTime dt) => _dateTimeFormatter.format(dt);
  static String shortDate(DateTime dt) => _shortDateFormatter.format(dt);

  static String distance(double meters, {bool imperial = false}) {
    if (imperial) {
      final feet = meters * 3.28084;
      if (feet < 1000) return '${feet.toStringAsFixed(0)} ft';
      return '${(meters / 1609.34).toStringAsFixed(2)} mi';
    }
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  static String speed(double mps, {bool imperial = false}) {
    if (imperial) return '${(mps * 2.23694).toStringAsFixed(1)} mph';
    return '${(mps * 3.6).toStringAsFixed(1)} km/h';
  }

  static String calories(double cal) {
    if (cal >= 1000) return '${(cal / 1000).toStringAsFixed(1)} kcal';
    return '${cal.toStringAsFixed(0)} cal';
  }

  static String steps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }

  static String duration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  static String battery(int percent) => '$percent%';

  static String weight(double kg, {bool imperial = false}) {
    if (imperial) return '${(kg * 2.20462).toStringAsFixed(1)} lb';
    return '${kg.toStringAsFixed(1)} kg';
  }
}
