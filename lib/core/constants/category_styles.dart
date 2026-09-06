import 'package:flutter/material.dart';

/// Single source of truth for expense-category icon/color styling.
///
/// Colours are spread around the hue wheel so adjacent slices in the monthly
/// breakdown donut stay easy to tell apart.
class CategoryStyles {
  CategoryStyles._();

  static IconData icon(String category) {
    switch (category) {
      case 'Vegetables and Provision':
        return Icons.shopping_basket;
      case 'Staff Advance':
        return Icons.person_outline;
      case 'Staff Salaries':
        return Icons.payments;
      case 'Snacks':
        return Icons.cookie;
      case 'Chicken':
        return Icons.set_meal;
      case 'Maintenance':
        return Icons.build;
      case 'Waste Removal':
        return Icons.delete_sweep;
      case 'EB':
        return Icons.bolt;
      case 'Wifi Bill':
        return Icons.wifi;
      case 'Returned to Student':
        return Icons.assignment_return;
      default:
        return Icons.receipt;
    }
  }

  static Color color(String category) {
    switch (category) {
      case 'Vegetables and Provision':
        return const Color(0xFF33D9B2); // teal
      case 'Staff Advance':
        return const Color(0xFF3FD3F7); // cyan
      case 'Staff Salaries':
        return const Color(0xFFB388FF); // violet
      case 'Snacks':
        return const Color(0xFFFFA26B); // orange
      case 'Chicken':
        return const Color(0xFFFF7A85); // coral red
      case 'Maintenance':
        return const Color(0xFF7FB3FF); // steel blue
      case 'Waste Removal':
        return const Color(0xFFA5D66F); // lime
      case 'EB':
        return const Color(0xFFFFD54F); // yellow
      case 'Wifi Bill':
        return const Color(0xFFF48FB1); // pink
      case 'Returned to Student':
        return const Color(0xFFA8ACC0); // slate
      default:
        return const Color(0xFF6B7094);
    }
  }
}
