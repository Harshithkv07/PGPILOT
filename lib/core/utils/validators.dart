class Validators {
  // Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Validate phone number (10 digits). Optional: blank is accepted, but if
  // something is typed it still has to look like a phone number.
  static String? validateOptionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 10) {
      return 'Phone number must be 10 digits';
    }

    return null;
  }

  // Validate date format (DD/MM/YYYY). Optional: blank is accepted.
  static String? validateOptionalDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(value)) {
      return 'Date must be in DD/MM/YYYY format';
    }

    return null;
  }

  // Validate number
  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    if (int.tryParse(value) == null) {
      return '$fieldName must be a valid number';
    }
    
    return null;
  }
}
