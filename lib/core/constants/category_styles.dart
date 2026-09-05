import 'package:flutter/material.dart';

/// Single source of truth for expense-category icon/color styling.
///
/// Previously this switch statement was duplicated verbatim in
/// accounts_screen.dart and monthly_summary_sheet.dart.
class CategoryStyles {
  CategoryStyles._();

  static IconData icon(String category) {
    switch (category) {
      case 'Staff Advance':
        return Icons.person_outline;
      case 'Groceries':
        return Icons.shopping_cart;
      case 'Maintenance':
        return Icons.build;
      case 'Staff Salaries':
        return Icons.payments;
      case 'Wi-Fi':
        return Icons.wifi;
      case 'Other':
        return Icons.more_horiz;
      default:
        return Icons.receipt;
    }
  }

  static Color color(String category) {
    switch (category) {
      case 'Staff Advance':
        return const Color(0xFF3FD3F7);
      case 'Groceries':
        return const Color(0xFF33D9B2);
      case 'Maintenance':
        return const Color(0xFFFFC857);
      case 'Staff Salaries':
        return const Color(0xFFB388FF);
      case 'Wi-Fi':
        return const Color(0xFFFF8FA3);
      case 'Other':
        return const Color(0xFF6B7094);
      default:
        return const Color(0xFFA8ACC0);
    }
  }
}
