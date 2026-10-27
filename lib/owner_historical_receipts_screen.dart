import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/widgets/entry_components.dart';

/// Read-only owner history. The RPC authenticates the owner and scopes every
/// row by its server-side workspace identity, even after plan expiration.
class OwnerHistoricalReceiptsScreen extends StatefulWidget {
  const OwnerHistoricalReceiptsScreen({
    super.key,
    this.loadReceipts,
    this.loadDetail,
  });

  final Future<List<Map<String, dynamic>>> Function()? loadReceipts;
  final Future<Map<String, dynamic>?> Function(String)? loadDetail;

  @override
  State<OwnerHistoricalReceiptsScreen> createState() =>
      _OwnerHistoricalReceiptsScreenState();
}

class _OwnerHistoricalReceiptsScreenState
    extends State<OwnerHistoricalReceiptsScreen> {
  late Future<List<Map<String, dynamic>>> receipts = _load();

  Future<List<Map<String, dynamic>>> _load() =>
      (widget.loadReceipts ?? ApiService.ownerHistoricalReceipts)();

  Future<void> _open(String ticketId) async {
    try {
      final detail =
          await (widget.loadDetail ?? ApiService.ownerHistoricalReceiptDetail)(
            ticketId,
          );
      if (!mounted) return;
      if (detail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt is unavailable.')),
        );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt details',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  _field(
                    'Verified amount',
                    '${detail['verified_amount'] ?? '—'} ${detail['currency'] ?? ''}',
                  ),
                  _field('Provider', detail['provider']?.toString() ?? '—'),
                  _field(
                    'Transaction reference',
                    detail['transaction_reference']?.toString() ?? '—',
                  ),
                  _field(
                    'Transaction date',
                    detail['transaction_at']?.toString() ?? 'Not provided',
                  ),
                  _field(
                    'Verified at',
                    detail['verified_at']?.toString() ?? '—',
                  ),
                  _field(
                    'Business completion',
                    detail['completion_status']?.toString() ?? '—',
                  ),
                  _field(
                    'Original receipt',
                    detail['evidence_status']?.toString() ?? 'missing_original',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Original image access is not available in read-only mode yet.',
                    style: TextStyle(color: EntryColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load this receipt. Try again.'),
          ),
        );
      }
    }
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: EntryColors.muted)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ChekmiEntryTheme(
    child: Scaffold(
      appBar: AppBar(title: const Text('Past receipts')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: receipts,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() => receipts = _load()),
                      child: const Text('Could not load receipts. Retry'),
                    ),
                  );
                }
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('No verified receipts yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(
                        '${row['verified_amount'] ?? '—'} ${row['currency'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${row['provider'] ?? 'Provider'} · ${row['transaction_reference'] ?? 'No reference'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _open(row['ticket_id'].toString()),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
