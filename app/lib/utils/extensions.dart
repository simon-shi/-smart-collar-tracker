import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Date/Time extensions
extension DateTimeExtensions on DateTime {
  String get displayDate => DateFormat('MMM d, yyyy').format(this);
  String get displayTime => DateFormat('h:mm a').format(this);
  String get displayDateTime => DateFormat('MMM d, h:mm a').format(this);
  String get isoDate =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  String get relativeTime {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return displayDate;
  }
}

// String extensions
extension StringExtensions on String {
  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get titleCase {
    return split(' ').map((w) => w.capitalized).join(' ');
  }

  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }
}

// Color extensions
extension ColorExtensions on Color {
  String get hexString {
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Color get darken {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  Color get lighten {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
  }
}

// BuildContext extensions
extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// List extensions
extension ListExtensions<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}

// Int extensions
extension IntExtensions on int {
  String get batteryIcon {
    if (this >= 80) return '🔋';
    if (this >= 50) return '🔋';
    if (this >= 20) return '🪫';
    return '🪫';
  }
}

// Double extensions
extension DoubleExtensions on double {
  String toFixed(int places) => toStringAsFixed(places);
}
