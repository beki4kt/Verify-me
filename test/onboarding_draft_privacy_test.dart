import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:verify_me/offline_storage.dart';

void main() {
  test('persists choices but excludes identity, account and secrets', () {
    final safe = DeviceStorage.sanitizeOnboardingDraft({
      'onboarding_version': 2,
      'step': 4,
      'category_id': 'shop_retail',
      'plan': 'basic',
      'business': 'Private shop',
      'owner': 'Private owner',
      'phone': '+251900000001',
      'email': 'owner@example.test',
      'account': '1234567890',
      'password': 'never-save-this',
      'otp': '123456',
    });
    expect(safe, {
      'onboarding_version': 2,
      'step': 4,
      'category_id': 'shop_retail',
      'plan': 'basic',
    });
  });

  test(
    'opening device settings removes sensitive fields from an old draft',
    () async {
      final directory = await Directory.systemTemp.createTemp('chekmi-draft-');
      Hive.init(directory.path);
      final box = await Hive.openBox('device_settings');
      await box.put('owner_onboarding_draft', {
        'step': 4,
        'phone': '+251900000001',
        'account': '1234567890',
        'plan': 'pro',
      });
      await DeviceStorage.init();
      expect(DeviceStorage.getOnboardingDraft(), {'step': 4, 'plan': 'pro'});
      expect(
        (box.get('owner_onboarding_draft') as Map).containsKey('phone'),
        false,
      );
      expect(
        (box.get('owner_onboarding_draft') as Map).containsKey('account'),
        false,
      );
      await box.close();
      await directory.delete(recursive: true);
    },
  );
}
