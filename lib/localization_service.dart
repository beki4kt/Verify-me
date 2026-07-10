import 'package:flutter/material.dart';

class LocalizationService extends ChangeNotifier {
  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // General
      'secure_login': 'SECURE SYSTEM LOGIN',
      'phone_hint': 'Phone Number',
      'password_hint': 'Password',
      'authenticate': 'AUTHENTICATE',
      'switch_lang': 'አማርኛ',
      // Admin Dashboard
      'master_operations': 'MASTER OPERATIONS',
      'real_time_metrics': 'REAL-TIME METRICS (TODAY)',
      'revenue': 'REVENUE',
      'tips_logged': 'TIPS LOGGED',
      'open_tables': 'OPEN TABLES CURRENTLY IN SYSTEM',
      'active_bills': 'ACTIVE BILLS',
      'license_usage': 'LICENSE USAGE & UPGRADES',
      'seats_provisioned': 'Staff Seats Provisioned',
      'team_directory': 'TEAM DIRECTORY (TAP TO EDIT)',
      'provision_staff': 'PROVISION NEW STAFF',
      'full_name': 'FULL NAME',
      'system_role': 'SYSTEM ROLE',
      'save_user': 'SAVE USER',
      'update_staff': 'UPDATE STAFF',
    },
    'am': {
      // General
      'secure_login': 'ወደ ሲስተም ይግቡ',
      'phone_hint': 'ስልክ ቁጥር',
      'password_hint': 'የይለፍ ቃል',
      'authenticate': 'ግባ',
      'switch_lang': 'English',
      // Admin Dashboard
      'master_operations': 'ዋና ስራዎች (Admin)',
      'real_time_metrics': 'የእለቱ ገቢ ትንታኔ',
      'revenue': 'አጠቃላይ ገቢ',
      'tips_logged': 'ቲፕ (ጉርሻ)',
      'open_tables': 'በስርዓቱ ውስጥ ያሉ ክፍት ሂሳቦች',
      'active_bills': 'ያልተዘጉ ሂሳቦች',
      'license_usage': 'የፍቃድ አጠቃቀም',
      'seats_provisioned': 'የተመዘገቡ ሰራተኞች',
      'team_directory': 'የሰራተኞች ማውጫ (ለማስተካከል ይጫኑ)',
      'provision_staff': 'አዲስ ሰራተኛ መዝግብ',
      'full_name': 'ሙሉ ስም',
      'system_role': 'የስራ ድርሻ',
      'save_user': 'አስቀምጥ',
      'update_staff': 'አዘምን',
    }
  };

  void toggleLanguage() {
    _currentLanguage = _currentLanguage == 'en' ? 'am' : 'en';
    notifyListeners();
  }

  String translate(String key) {
    return _localizedValues[_currentLanguage]?[key] ?? key;
  }
}