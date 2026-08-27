import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'offline_storage.g.dart';

@HiveType(typeId: 0)
class PendingTicket extends HiveObject {
  @HiveField(0)
  final String transactionId;

  @HiveField(1)
  final String endpoint;

  @HiveField(2)
  final int timestamp;

  // NEW: Holds the full ticket data (Amount, Waiter ID, Bank) for the Cashier
  @HiveField(3)
  final String? ticketDataJson;

  PendingTicket({
    required this.transactionId,
    required this.endpoint,
    required this.timestamp,
    this.ticketDataJson,
  });
}

class SyncManager {
  static const String _boxName = 'pending_tickets_queue';
  final ValueNotifier<int> quarantinedLegacyCount = ValueNotifier<int>(0);

  // Singleton pattern for easy access across the app
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  static Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PendingTicketAdapter());
    await Hive.openBox<PendingTicket>(_boxName);
    instance.quarantinedLegacyCount.value = Hive.box<PendingTicket>(_boxName)
        .length;
    await DeviceStorage.init(); // Initialize the Business Lock Storage
  }

  /// Financial writes cannot be verified safely without a provider connection.
  /// Legacy records are retained only for support-assisted inspection and are
  /// never replayed, reassigned, or silently deleted.
  void startBackgroundSync() {
    final box = Hive.box<PendingTicket>(_boxName);
    quarantinedLegacyCount.value = box.length;
    if (box.isNotEmpty) {
      debugPrint(
        '${box.length} legacy offline payment record(s) quarantined; rescan online.',
      );
    }
  }

  List<Map<String, dynamic>> quarantinedLegacyRecords() {
    final records = Hive.box<PendingTicket>(_boxName).values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return records
        .map(
          (ticket) => {
            'reference': ticket.transactionId,
            'created_at': DateTime.fromMillisecondsSinceEpoch(ticket.timestamp)
                .toIso8601String(),
            'status': 'quarantined',
            'action': 'Rescan while online',
          },
        )
        .toList(growable: false);
  }

  Future<void> acknowledgeAndRemoveLegacyRecord(String reference) async {
    final box = Hive.box<PendingTicket>(_boxName);
    for (final ticket in box.values.toList()) {
      if (ticket.transactionId == reference) {
        await ticket.delete();
      }
    }
    quarantinedLegacyCount.value = box.length;
  }

  void stopBackgroundSync() {}
}

// --- PHASE 1: BUSINESS LAYER DEVICE LOCKING ---
class DeviceStorage {
  static const String _boxName = 'device_settings';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Future<void> lockDeviceToBusiness(
    String businessId,
    String businessName,
    String businessCode,
  ) async {
    final box = Hive.box(_boxName);
    await box.put('locked_business_id', businessId);
    await box.put('locked_business_name', businessName);
    await box.put('locked_business_code', businessCode);
  }

  static Future<void> clearDeviceLock() async {
    final box = Hive.box(_boxName);
    await box.delete('locked_business_id');
    await box.delete('locked_business_name');
    await box.delete('locked_business_code');
  }

  static Map<String, String?> getLockedBusiness() {
    final box = Hive.box(_boxName);
    if (!box.isOpen) return {'id': null, 'name': null, 'code': null};
    return {
      'id': box.get('locked_business_id'),
      'name': box.get('locked_business_name'),
      'code': box.get('locked_business_code'),
    };
  }

  static ThemeMode getThemeMode() {
    if (!Hive.isBoxOpen(_boxName)) return ThemeMode.dark;
    final box = Hive.box(_boxName);
    return box.get('theme_mode') == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final box = Hive.box(_boxName);
    await box.put('theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
  }

  static String getLanguageCode() {
    if (!Hive.isBoxOpen(_boxName)) return 'en';
    final box = Hive.box(_boxName);
    return box.get('language_code') == 'am' ? 'am' : 'en';
  }

  static Future<void> saveLanguageCode(String languageCode) async {
    final box = Hive.box(_boxName);
    await box.put('language_code', languageCode == 'am' ? 'am' : 'en');
  }

  static bool getHideTipBalance() {
    if (!Hive.isBoxOpen(_boxName)) return false;
    return Hive.box(_boxName).get('hide_tip_balance', defaultValue: false)
        as bool;
  }

  static Future<void> saveHideTipBalance(bool hidden) async {
    await Hive.box(_boxName).put('hide_tip_balance', hidden);
  }
}
