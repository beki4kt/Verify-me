import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

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
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Singleton pattern for easy access across the app
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  static Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PendingTicketAdapter());
    await Hive.openBox<PendingTicket>(_boxName);
    await DeviceStorage.init(); // Initialize the Business Lock Storage
  }

  // --- ORIGINAL METHOD (For standard verifications) ---
  Future<void> enqueueTicket(PendingTicket ticket) async {
    final box = Hive.box<PendingTicket>(_boxName);
    await box.add(ticket);
    debugPrint("Ticket queued offline: ${ticket.transactionId}");
  }

  // --- NEW METHOD (For the Cashier Ledger fallback) ---
  Future<void> saveOfflineTicket(Map<String, dynamic> ticketData) async {
    final ticket = PendingTicket(
      transactionId: ticketData['transaction_ref'],
      endpoint: 'CASHIER_SUBMISSION', // Identifier flag
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ticketDataJson: jsonEncode(ticketData),
    );
    await enqueueTicket(ticket);
  }

  void startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _attemptSync();
    });
  }

  Future<void> _attemptSync() async {
    if (_isSyncing) return;

    final box = Hive.box<PendingTicket>(_boxName);
    if (box.isEmpty) return;

    // Check actual hardware connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    _isSyncing = true;

    try {
      final pendingTickets = box.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (var ticket in pendingTickets) {
        
        // Scenario A: It's a full ticket submission for the Cashier
        if (ticket.endpoint == 'CASHIER_SUBMISSION' && ticket.ticketDataJson != null) {
           try {
             final data = jsonDecode(ticket.ticketDataJson!);
             await ApiService.submitVerifiedTicket(
               transactionId: data['transaction_ref'],
               amount: data['bill_amount'].toString(),
               bankName: data['bank']
             );
             // If the above line succeeds, delete it from the offline queue
             debugPrint("Offline Cashier Ticket synced successfully: ${ticket.transactionId}");
             await ticket.delete();
           } catch (e) {
             // Network failed during sync, keep it in the queue for the next timer cycle
             break; 
           }
        } 
        
        // Scenario B: It's a standard verification
        else {
          VerificationResult result = await ApiService.verifyTransaction(
            ticket.transactionId,
            ticket.endpoint,
          );

          if (result.isSuccess) {
            debugPrint("Offline ticket synced successfully: ${ticket.transactionId}");
            await ticket.delete(); 
          } else if (result.errorMessage != null && !result.errorMessage!.contains('Network Error')) {
            debugPrint("Offline ticket rejected by server: ${ticket.transactionId}. Removing from queue.");
            await ticket.delete();
          } else {
            // Network error persists, break loop and try next cycle
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Background sync exception: $e");
    } finally {
      _isSyncing = false;
    }
  }

  void stopBackgroundSync() {
    _syncTimer?.cancel();
  }
}

// --- PHASE 1: BUSINESS LAYER DEVICE LOCKING ---
class DeviceStorage {
  static const String _boxName = 'device_settings';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  static Future<void> lockDeviceToBusiness(String businessId, String businessName, String businessCode) async {
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
}