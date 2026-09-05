import 'package:flutter/material.dart';

/// Central color palette for PGPilot's premium dark theme.
///
/// Backgrounds carry a faint cool undertone (not pure black) so cards can
/// read as "elevated" via subtle tone shifts rather than harsh borders.
class AppColors {
  // Background Colors
  static const Color primaryBackground = Color(0xFF0B0B0F);
  static const Color secondaryBackground = Color(0xFF15151C);
  static const Color cardBackground = Color(0xFF1E1E27);
  static const Color cardBackgroundElevated = Color(0xFF262632);

  // Gold Accent Family
  static const Color primaryAccent = Color(0xFFD4AF37);
  static const Color accentHighlight = Color(0xFFF2C94C);
  static const Color accentDeep = Color(0xFF8A6D1F);
  static const Color secondaryAccent = Color(0xFFD4AF37);
  static const Color goldAccent = Color(0xFFD4AF37);

  // Status Colors - Room Availability
  static const Color roomFull = Color(0xFFFF5C7A);
  static const Color roomPartial = Color(0xFFFFC857);
  static const Color roomEmpty = Color(0xFF33D9B2);

  // Status Colors - Payment
  static const Color paymentPaid = Color(0xFF33D9B2);
  static const Color paymentPending = Color(0xFFFF5C7A);

  // Text Colors
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFA8ACC0);
  static const Color textMuted = Color(0xFF6B7094);

  // UI Elements
  static const Color borderColor = Color(0xFF2A2B38);
  static const Color borderColorSubtle = Color(0x1AFFFFFF);
  static const Color errorColor = Color(0xFFFF5C7A);
  static const Color successColor = Color(0xFF33D9B2);
  static const Color warningColor = Color(0xFFFFC857);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentHighlight, primaryAccent],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryBackground, secondaryBackground, primaryBackground],
  );
}
