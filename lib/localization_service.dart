import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    'Enter your restaurant workspace code. You only need to do this once on this device.':
        'የምግብ ቤትዎን የስራ ቦታ ኮድ ያስገቡ። በዚህ መሣሪያ ላይ አንድ ጊዜ ብቻ ያስፈልጋል።',
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
    'SIGN IN': 'ግባ',
    'SIGNING IN': 'በመግባት ላይ',
    'This is not your restaurant? Change workspace':
        'ይህ የእርስዎ ምግብ ቤት አይደለም? የስራ ቦታ ይቀይሩ',
    'Restaurant overview': 'የምግብ ቤት አጠቃላይ እይታ',
    'Overview': 'አጠቃላይ እይታ',
    'Team': 'ቡድን',
    'TOTAL REVENUE': 'ጠቅላላ ገቢ',
    'ACTIVE BILLS': 'ክፍት ሂሳቦች',
    'BANK DEPOSIT BREAKDOWN': 'የባንክ ገቢ ዝርዝር',
    'MASTER TRANSACTION LEDGER': 'ዋና የግብይት መዝገብ',
    'No verified transactions yet.': 'እስካሁን የተረጋገጠ ግብይት የለም።',
    'Ledger is clear.': 'መዝገቡ ባዶ ነው።',
    'No staff members found.': 'ምንም ሰራተኛ አልተገኘም።',
    'No active floor staff.': 'ንቁ የአዳራሽ ሰራተኛ የለም።',
    'Cashier terminal': 'የገንዘብ ተቀባይ ተርሚናል',
    'Waiter workspace': 'የአስተናጋጅ የስራ ቦታ',
    'Wallet': 'የገንዘብ ቦርሳ',
    'History': 'ታሪክ',
    'Scan': 'ስካን',
    'Tickets': 'ትኬቶች',
    'Scan receipt': 'ደረሰኝ ስካን',
    'Pending': 'በመጠባበቅ ላይ',
    'Settled': 'ተጠናቋል',
    'PENDING': 'በመጠባበቅ ላይ',
    'SETTLED': 'ተጠናቋል',
    'Queue is clear.': 'የሚጠብቅ ሂሳብ የለም።',
    'No settled tickets yet.': 'እስካሁን የተጠናቀቀ ትኬት የለም።',
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
    'CAPTURE RECEIPT': 'ደረሰኝ ያንሱ',
    'READING RECEIPT': 'ደረሰኙን በማንበብ ላይ',
    'Trial mode': 'የሙከራ ሁኔታ',
    'A guided, risk-free tour of CHEKMI': 'የCHEKMI ቀላልና ከአደጋ ነፃ ጉብኝት',
    'Choose a role': 'ሚና ይምረጡ',
    'Waiter': 'አስተናጋጅ',
    'Cashier': 'ገንዘብ ተቀባይ',
    'Admin': 'አስተዳዳሪ',
    'Today': 'ዛሬ',
    'Available tips': 'ያሉ ጉርሻዎች',
    'Open tickets': 'ክፍት ትኬቶች',
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
    'Connect your restaurant workspace when you are ready.':
        'ዝግጁ ሲሆኑ የምግብ ቤትዎን የስራ ቦታ ያገናኙ።',
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
    if (!isAmharic) return english;
    return _amharic[english] ?? english;
  }
}

extension LocalizationBuildContext on BuildContext {
  LocalizationService get localization => watch<LocalizationService>();
  String tr(String english) => localization.translate(english);
}
