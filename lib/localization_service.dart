import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_variant.dart';
import 'offline_storage.dart';

/// English and Amharic product copy with a safe English fallback.
class LocalizationService extends ChangeNotifier {
  LocalizationService() : _languageCode = DeviceStorage.getLanguageCode();

  String _languageCode;
  String get currentLanguage => _languageCode;
  Locale get locale => Locale(_languageCode);
  bool get isAmharic => _languageCode == 'am';

  static const Map<String, String> _amharic = {
    'Language': 'ቋንቋ',
    'Amharic': 'አማርኛ',
    'Light mode': 'ብሩህ ገጽታ',
    'Dark mode': 'ጨለማ ገጽታ',
    'Connect this terminal': 'ይህን ተርሚናል ያገናኙ',
    'Enter your business workspace code. You only need to do this once on this device.':
        'የድርጅትዎን የስራ ቦታ ኮድ ያስገቡ። በዚህ መሣሪያ ላይ አንድ ጊዜ ብቻ ያስፈልጋል።',
    'WORKSPACE CODE': 'የስራ ቦታ ኮድ',
    'CONNECT WORKSPACE': 'የስራ ቦታን አገናኝ',
    'CONNECTING': 'በማገናኘት ላይ',
    'Encrypted tenant connection': 'የተመሰጠረ የድርጅት ግንኙነት',
    'Explore before you connect': 'ከማገናኘትዎ በፊት ይመልከቱ',
    'TRY THE LIVE DEMO': 'የሙከራ ማሳያውን ይመልከቱ',
    'No account, setup, or payment required': 'መለያ፣ ዝግጅት ወይም ክፍያ አያስፈልግም',
    'Welcome back': 'እንኳን ደህና መጡ',
    'Sign in to continue to your shift.': 'ወደ ፈረቃዎ ለመቀጠል ይግቡ።',
    'Phone number': 'ስልክ ቁጥር',
    'Password': 'የይለፍ ቃል',
    'Sign in': 'ግባ',
    'Quick access': 'ፈጣን መግቢያ',
    'Change workspace': 'የስራ ቦታ ቀይር',
    'Open demo': 'ሙከራውን ክፈት',
    'SIGN IN': 'ግባ',
    'SIGNING IN': 'በመግባት ላይ',
    'This is not your business? Change workspace':
        'ይህ የእርስዎ ድርጅት አይደለም? የስራ ቦታ ይቀይሩ',
    'Business overview': 'የድርጅት አጠቃላይ እይታ',
    'Overview': 'አጠቃላይ እይታ',
    'Team': 'ቡድን',
    'TOTAL REVENUE': 'ጠቅላላ ገቢ',
    'OPEN PAYMENTS': 'ክፍት ሂሳቦች',
    'BANK DEPOSIT BREAKDOWN': 'የባንክ ገቢ ዝርዝር',
    'MASTER TRANSACTION LEDGER': 'ዋና የግብይት መዝገብ',
    'PAYMENT METHODS': 'የክፍያ ዘዴዎች',
    'TRANSACTIONS': 'ግብይቶች',
    'No verified transactions yet.': 'እስካሁን የተረጋገጠ ግብይት የለም።',
    'Ledger is clear.': 'መዝገቡ ባዶ ነው።',
    'No staff members found.': 'ምንም ሰራተኛ አልተገኘም።',
    'No active staff.': 'ንቁ ሰራተኛ የለም።',
    'Manage': 'አስተዳድር',
    'Cashier terminal': 'የገንዘብ ተቀባይ ተርሚናል',
    'Payment workspace': 'የክፍያ የስራ ቦታ',
    'Activity': 'እንቅስቃሴ',
    'VERIFIED PAYMENTS': 'የተረጋገጡ ክፍያዎች',
    'Verified payments': 'የተረጋገጡ ክፍያዎች',
    'VERIFY PAYMENT': 'ክፍያ አረጋግጥ',
    'NEW PAYMENT': 'አዲስ ክፍያ',
    'LINK PAYMENT TO': 'ክፍያውን ያገናኙ',
    'Invoice': 'የክፍያ መጠየቂያ',
    'Invoice number': 'የክፍያ መጠየቂያ ቁጥር',
    'Order': 'ትዕዛዝ',
    'Order number': 'የትዕዛዝ ቁጥር',
    'Customer': 'ደንበኛ',
    'Customer reference': 'የደንበኛ መለያ',
    'Table': 'ጠረጴዛ',
    'Table number': 'የጠረጴዛ ቁጥር',
    'Other': 'ሌላ',
    'Payment note': 'የክፍያ ማስታወሻ',
    'optional': 'አማራጭ',
    'Leave blank to use the bank reference.': 'የባንክ መለያውን ለመጠቀም ባዶ ይተዉት።',
    'AMOUNT DUE (ETB)': 'የሚከፈል መጠን (ብር)',
    'Staff tips': 'የሰራተኞች ጉርሻ',
    'For teams that accept tips': 'ጉርሻ ለሚቀበሉ ቡድኖች',
    'Wallet': 'የገንዘብ ቦርሳ',
    'History': 'ታሪክ',
    'Scan': 'ስካን',
    'Payments': 'ክፍያዎች',
    'Scan receipt': 'ደረሰኝ ስካን',
    'Pending': 'በመጠባበቅ ላይ',
    'Settled': 'ተጠናቋል',
    'PENDING': 'በመጠባበቅ ላይ',
    'SETTLED': 'ተጠናቋል',
    'Queue is clear.': 'የሚጠብቅ ሂሳብ የለም።',
    'No settled payments yet.': 'እስካሁን የተጠናቀቀ ክፍያ የለም።',
    'No payments yet.': 'እስካሁን ክፍያ የለም።',
    'No payments yet. Use Scan to add one.': 'እስካሁን ክፍያ የለም። ለመጨመር ስካንን ይጠቀሙ።',
    'Connection error.': 'የግንኙነት ስህተት።',
    'AVAILABLE TIPS': 'ያሉ ጉርሻዎች',
    'All recorded tips are settled': 'ሁሉም የተመዘገቡ ጉርሻዎች ተጠናቀዋል',
    'Total checks': 'ጠቅላላ ደረሰኞች',
    'View receipts': 'ደረሰኞችን ይመልከቱ',
    'Verified volume': 'የተረጋገጠ መጠን',
    'RECENT SCANS': 'የቅርብ ጊዜ ስካኖች',
    'Verified and failed attempts': 'የተሳኩና ያልተሳኩ ሙከራዎች',
    'No receipt scans recorded yet.': 'እስካሁን የተመዘገበ የደረሰኝ ስካን የለም።',
    'Checked receipts': 'የተፈተሹ ደረሰኞች',
    'No checked receipts yet.': 'እስካሁን የተፈተሸ ደረሰኝ የለም።',
    'Choose a payment provider': 'የክፍያ አቅራቢ ይምረጡ',
    'Payment method': 'የክፍያ ዘዴ',
    'Use manual entry in Safari. Camera scanning works in the iPhone app.':
        'በSafari ውስጥ በእጅ ያስገቡ። የካሜራ ስካን በiPhone መተግበሪያ ይሰራል።',
    'CAPTURE RECEIPT': 'ደረሰኝ ያንሱ',
    'READING RECEIPT': 'ደረሰኙን በማንበብ ላይ',
    'Trial mode': 'የሙከራ ሁኔታ',
    'A guided, risk-free tour of CHEKMI': 'የCHEKMI ቀላልና ከአደጋ ነፃ ጉብኝት',
    'Choose a role': 'ሚና ይምረጡ',
    'Staff': 'ሰራተኛ',
    'Cashier': 'ገንዘብ ተቀባይ',
    'Admin': 'አስተዳዳሪ',
    'Demo': 'ሙከራ',
    'Help': 'እገዛ',
    'Refresh': 'አድስ',
    'Cancel': 'ሰርዝ',
    'Today': 'ዛሬ',
    'Available tips': 'ያሉ ጉርሻዎች',
    'Open payments': 'ክፍት ክፍያዎች',
    'Staff online': 'በመስመር ላይ ያሉ ሰራተኞች',
    'Verify a receipt': 'ደረሰኝ ያረጋግጡ',
    'Verify receipt': 'ደረሰኝ ያረጋግጡ',
    'Receipt verified': 'ደረሰኙ ተረጋግጧል',
    'Select a provider, then verify the sample receipt.':
        'አቅራቢ ይምረጡ፣ ከዚያ የምሳሌውን ደረሰኝ ያረጋግጡ።',
    'VERIFY RECEIPT': 'ደረሰኝ አረጋግጥ',
    'VERIFIED': 'ተረጋግጧል',
    'Preview verification': 'ማረጋገጫውን ይመልከቱ',
    'A sample Telebirr payment was verified successfully.':
        'የምሳሌ Telebirr ክፍያ በትክክል ተረጋግጧል።',
    'Payment verified': 'ክፍያው ተረጋግጧል',
    'Sample data only — no live transaction was created.':
        'የምሳሌ መረጃ ብቻ ነው፤ እውነተኛ ግብይት አልተፈጠረም።',
    'EXIT TRIAL': 'ሙከራውን ዝጋ',
    'Ready to use CHEKMI?': 'CHEKMIን ለመጠቀም ዝግጁ ነዎት?',
    'Connect your business workspace when you are ready.':
        'ዝግጁ ሲሆኑ የድርጅትዎን የስራ ቦታ ያገናኙ።',
  };

  /// Short, action-first English used by the Test 2 review build.
  ///
  /// Operational warnings, confirmations, and legal copy deliberately keep
  /// their full wording. Only navigation, headings, helper copy, and common
  /// actions are condensed.
  static const Map<String, String> _minimalEnglish = {
    'Connect this terminal': 'Workspace',
    'Enter your business workspace code. You only need to do this once on this device.':
        'Enter your code',
    'WORKSPACE CODE': 'CODE',
    'CONNECT WORKSPACE': 'CONNECT',
    'Explore before you connect': 'Preview',
    'TRY THE LIVE DEMO': 'DEMO',
    'No account, setup, or payment required': 'No setup',
    'Encrypted tenant connection': 'SECURE',
    'Welcome back': 'Sign in',
    'Sign in to continue to your shift.': 'Staff access',
    'This is not your business? Change workspace': 'Change workspace',
    'Business overview': 'Overview',
    'TOTAL REVENUE': 'REVENUE',
    'OPEN PAYMENTS': 'OPEN PAYMENTS',
    'BANK DEPOSIT BREAKDOWN': 'DEPOSITS',
    'MASTER TRANSACTION LEDGER': 'TRANSACTIONS',
    'No verified transactions yet.': 'No transactions',
    'Ledger is clear.': 'No transactions',
    'No staff members found.': 'No staff',
    'No active staff.': 'No active staff',
    'Cashier terminal': 'Cashier',
    'Payment workspace': 'Staff',
    'No settled payments yet.': 'No payments',
    'Queue is clear.': 'Queue clear',
    'All recorded tips are settled': 'Settled',
    'Total checks': 'Checks',
    'View receipts': 'Receipts',
    'Verified volume': 'Volume',
    'RECENT SCANS': 'SCANS',
    'Verified and failed attempts': 'Recent activity',
    'No receipt scans recorded yet.': 'No scans',
    'Checked receipts': 'Receipts',
    'No checked receipts yet.': 'No receipts',
    'Choose a payment provider': 'Provider',
    'CAPTURE RECEIPT': 'CAPTURE',
    'READING RECEIPT': 'READING',
    'Trial mode': 'Demo',
    'A guided, risk-free tour of CHEKMI': 'Offline preview',
    'Choose a role': 'Role',
    'Available tips': 'Tips',
    'Open payments': 'Open',
    'Staff online': 'Online',
    'Verify a receipt': 'Verify',
    'Verify receipt': 'Verify',
    'Receipt verified': 'Verified',
    'Select a provider, then verify the sample receipt.': 'Choose and verify',
    'Preview verification': 'Preview',
    'A sample Telebirr payment was verified successfully.': 'Payment verified',
    'Sample data only — no live transaction was created.': 'Demo data',
    'Ready to use CHEKMI?': 'Go live?',
    'Connect your business workspace when you are ready.': 'Connect workspace',
  };

  Future<void> toggleLanguage() => setLanguage(isAmharic ? 'en' : 'am');

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'am') return;
    if (_languageCode == languageCode) return;
    _languageCode = languageCode;
    notifyListeners();
    await DeviceStorage.saveLanguageCode(languageCode);
  }

  String translate(String english) {
    final copy = AppVariant.usesMinimalCopy
        ? (_minimalEnglish[english] ?? english)
        : english;
    if (!isAmharic) return copy;
    return _amharic[copy] ?? _amharic[english] ?? copy;
  }
}

extension LocalizationBuildContext on BuildContext {
  LocalizationService get localization => watch<LocalizationService>();
  String tr(String english) => localization.translate(english);
}
