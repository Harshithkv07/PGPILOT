import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  // Format phone number for WhatsApp (remove spaces, dashes, etc.)
  static String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add country code if not present (assuming India 91)
    if (cleaned.length == 10) {
      cleaned = '91$cleaned';
    } else if (!cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = '91$cleaned';
    }
    
    // Return digits only (no + sign for wa.me URLs)
    return cleaned;
  }

  // Send welcome message to student
  static Future<bool> sendWelcomeMessage(String phone, String name, String roomNumber) async {
    final formattedPhone = _formatPhoneNumber(phone);
    final message = 'Hello $name! Welcome to our PG. You have been assigned Room $roomNumber. '
        'We hope you have a comfortable stay with us. Feel free to reach out if you need anything!';
    
    return await _sendWhatsAppMessage(formattedPhone, message);
  }

  // Send rent reminder
  static Future<bool> sendRentReminder(String phone, String name, String roomNumber, int amountDue) async {
    final formattedPhone = _formatPhoneNumber(phone);
    final message = 'Hi $name, gentle reminder that rent for Room $roomNumber is pending. '
        'Your total due amount is ₹$amountDue. '
        'Please make the payment at your earliest convenience using the QR code link below:\n\n'
        '[YOUR_QR_CODE_LINK_HERE]\n\n'
        'Thank you!';
    
    return await _sendWhatsAppMessage(formattedPhone, message);
  }

  // Send custom message
  static Future<bool> sendCustomMessage(String phone, String message) async {
    final formattedPhone = _formatPhoneNumber(phone);
    return await _sendWhatsAppMessage(formattedPhone, message);
  }

  // Core method to send WhatsApp message
  static Future<bool> _sendWhatsAppMessage(String phone, String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    
    // Try primary URL scheme (wa.me - works on both web and mobile)
    final waUrl = 'https://wa.me/$phone?text=$encodedMessage';
    final waUri = Uri.parse(waUrl);
    
    try {
      // Try launching directly - canLaunchUrl can be unreliable on Android
      final launched = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      print('wa.me scheme failed: $e');
    }
    
    // Try fallback URL scheme (whatsapp:// - app-specific)
    final whatsappUrl = 'whatsapp://send?phone=$phone&text=$encodedMessage';
    final whatsappUri = Uri.parse(whatsappUrl);
    
    try {
      final launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      print('whatsapp:// scheme failed: $e');
    }
    
    return false;
  }
}
