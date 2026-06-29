import 'dart:async';
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

  PendingTicket({
    required this.transactionId,
    required this.endpoint,
    required this.timestamp,
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
  }

  Future<void> enqueueTicket(PendingTicket ticket) async {
    final box = Hive.box<PendingTicket>(_boxName);
    await box.add(ticket);
    debugPrint("Ticket queued offline: ${ticket.transactionId}");
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
        // Attempt to verify via the existing ApiService
        VerificationResult result = await ApiService.verifyTransaction(
          ticket.transactionId,
          ticket.endpoint,
        );

        if (result.isSuccess) {
          debugPrint("Offline ticket synced successfully: ${ticket.transactionId}");
          await ticket.delete(); 
        } else if (result.errorMessage != null && !result.errorMessage!.contains('Network Error')) {
          // If it failed for a hard reason (e.g., invalid ID, already used), remove it so it doesn't block the queue
          debugPrint("Offline ticket rejected by server: ${ticket.transactionId}. Removing from queue.");
          await ticket.delete();
        } else {
          // Network error persists, break loop and try next cycle
          break;
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