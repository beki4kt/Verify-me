import 'package:flutter/material.dart';

class LocalizationService extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  bool get isAmharic => _currentLocale.languageCode == 'am';

  void toggleLanguage() {
    _currentLocale = isAmharic ? const Locale('en') : const Locale('am');
    notifyListeners();
  }

  String translate(String key) {
    return _localizedValues[_currentLocale.languageCode]?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'VERIFY-ME V1.0',
      'select_workspace': 'Select\nWorkspace.',
      'waiter': 'WAITER',
      'waiter_sub': 'Mobile receipt scanning & queuing',
      'cashier': 'CASHIER',
      'cashier_sub': 'Live payment feed & table linking',
      'admin': 'ADMIN',
      'admin_sub': 'Analytics & system management',
      'cashier_terminal': 'CASHIER TERMINAL',
      'unassigned': 'UNASSIGNED VERIFICATIONS',
      'active_waitstaff': 'ACTIVE WAITSTAFF',
      'cleared_ledger': 'CLEARED LEDGER',
      'flag_reject': 'FLAG / REJECT',
      'live_feed': 'LIVE FEED',
      'waiter_dashboard': 'WAITER DASHBOARD',
      'my_scans': 'MY SCANS',
      'scan_receipt': 'SCAN RECEIPT',
      'pending': 'Pending',
      'cleared': 'Cleared',
      'rejected': 'Rejected',
      'assign_prompt': 'Tap waiter to assign payment',
      'queue_clear': 'Queue is clear. Waiting for scans.',
      'no_scans': 'No scans yet today.',
    },
    'am': {
      'app_title': 'ቬሪፋይ-ሚ (VERIFY-ME)',
      'select_workspace': 'የስራ ቦታ\nይምረጡ።',
      'waiter': 'አስተናጋጅ',
      'waiter_sub': 'የሞባይል ደረሰኝ ስካን እና ማረጋገጫ',
      'cashier': 'ካሼር (ገንዘብ ተቀባይ)',
      'cashier_sub': 'የቀጥታ ክፍያዎች እና አስተናጋጅ ማገናኛ',
      'admin': 'አስተዳዳሪ (ADMIN)',
      'admin_sub': 'የስርዓት እና የሂሳብ አስተዳደር',
      'cashier_terminal': 'የካሼር ተርሚናል',
      'unassigned': 'ያልተመደቡ ክፍያዎች',
      'active_waitstaff': 'ንቁ አስተናጋጆች',
      'cleared_ledger': 'የተረጋገጡ ዝርዝሮች',
      'flag_reject': 'አግድ / ውድቅ አድርግ',
      'live_feed': 'የቀጥታ ክፍያዎች',
      'waiter_dashboard': 'አስተናጋጅ ዳሽቦርድ',
      'my_scans': 'የእኔ ቅኝቶች (Scans)',
      'scan_receipt': 'ደረሰኝ ስካን አድርግ',
      'pending': 'በመጠባበቅ ላይ',
      'cleared': 'ተረጋግጧል',
      'rejected': 'ውድቅ ተደርጓል',
      'assign_prompt': 'ክፍያውን ለመመደብ አስተናጋጁን ይንኩ',
      'queue_clear': 'ምንም አዲስ ክፍያ የለም።',
      'no_scans': 'ዛሬ ምንም ስካን አላደረጉም።',
    }
  };
}