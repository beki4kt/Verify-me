import 'package:flutter/material.dart';

import '../../offline_storage.dart';

class ThemeController extends ChangeNotifier {
  ThemeController() : _mode = DeviceStorage.getThemeMode();

  ThemeMode _mode;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    await DeviceStorage.saveThemeMode(_mode);
  }
}
