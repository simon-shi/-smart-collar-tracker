class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  static String? petName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pet name is required';
    }
    if (value.trim().length > 50) {
      return 'Pet name must be 50 characters or less';
    }
    return null;
  }

  static String? weight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Weight is required';
    }
    final weight = double.tryParse(value.trim());
    if (weight == null) {
      return 'Please enter a valid weight';
    }
    if (weight <= 0 || weight > 200) {
      return 'Weight must be between 0.1 and 200 kg';
    }
    return null;
  }

  static String? geofenceName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Geofence name is required';
    }
    if (value.trim().length > 100) {
      return 'Name must be 100 characters or less';
    }
    return null;
  }
}
