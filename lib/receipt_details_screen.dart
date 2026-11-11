import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';
import 'core/theme/app_colors.dart';

/// A shared, tenant-authorized receipt detail for every business preset.
/// Bank verification and the original image have separate, truthful states.
class ReceiptDetailsScreen extends StatefulWidget {
  const ReceiptDetailsScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  State<ReceiptDetailsScreen> createState() => _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends State<ReceiptDetailsScreen> {
  Map<String, dynamic>? _detail;
  Uint8List? _original;
  String? _error;
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ApiService.fetchVerifiedReceiptDetail(
        widget.ticketId,
      );
      if (detail == null) {
        throw StateError('Receipt not found or access denied.');
      }
      Uint8List? image;
      if (detail['evidence_status'] == 'stored') {
        try {
          image = await ApiService.fetchReceiptOriginalBytes(widget.ticketId);
        } catch (_) {
          /* Keep the verified details visible if storage is down. */
        }
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _original = image;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Receipt details are unavailable. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _attach(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 6 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a JPEG or PNG image under 6 MB.'),
          ),
        );
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      await ApiService.uploadReceiptOriginal(
        ticketId: widget.ticketId,
        bytes: bytes,
        source: source == ImageSource.camera ? 'camera' : 'photo_library',
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image was not saved. The payment remains verified; retry with the same image.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Not provided by provider';
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _row(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            title,
            style: const TextStyle(color: AppColors.textFaint, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  void _openOriginal() {
    final bytes = _original;
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF0B1020),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: .5,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  cacheWidth: 4096,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                tooltip: 'Close original receipt',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final status = detail?['evidence_status']?.toString() ?? 'missing_original';
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        title: const Text('Receipt Details'),
        backgroundColor: const Color(0xFF0B1020),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: TextButton(onPressed: _load, child: Text(_error!)),
            )
          : detail == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                const Text(
                  'PAYMENT VERIFIED',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${detail['verified_amount']} ${detail['currency'] ?? 'ETB'}',
                  style: const TextStyle(
                    color: Color(0xFFF4F7FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail['completion_status'] == 'settled'
                      ? 'Marked complete by workspace'
                      : 'Workspace review pending',
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _row('Provider', '${detail['provider'] ?? '—'}'),
                      _row(
                        'Reference',
                        '${detail['transaction_reference'] ?? '—'}',
                      ),
                      _row('Transaction', _date(detail['transaction_at'])),
                      _row('Verified at', _date(detail['verified_at'])),
                      _row('Verified by', '${detail['verified_by'] ?? '—'}'),
                      _row(
                        'Receiving',
                        '${detail['receiving_account_masked'] ?? '—'}',
                      ),
                      if (detail['reference_value'] != null)
                        _row(
                          '${detail['reference_kind'] ?? 'Context'}',
                          '${detail['reference_value']}',
                        ),
                      if (detail['expected_amount'] != null)
                        _row(
                          'Amount due',
                          '${detail['expected_amount']} ${detail['currency'] ?? 'ETB'}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  detail['evidence_source'] == 'legacy'
                      ? 'Legacy Receipt Image'
                      : 'Original Receipt',
                  style: TextStyle(
                    color: Color(0xFFF4F7FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                if (_original != null) ...[
                  if (detail['evidence_source'] == 'legacy')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'This older receipt was stored as a compressed image.',
                        style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _openOriginal,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: const Color(0xFF1A1F3D),
                        height: 210,
                        child: Image.memory(
                          _original!,
                          fit: BoxFit.contain,
                          cacheWidth: 640,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _openOriginal,
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('View Original'),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F3D),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      status == 'stored'
                          ? 'Original saved, but temporarily unavailable. Retry loading.'
                          : status == 'pending_upload'
                          ? 'Original image upload needs confirmation.'
                          : status == 'upload_failed'
                          ? 'Original image upload failed. The payment is still verified.'
                          : 'No original image was attached to this verified payment.',
                      style: const TextStyle(color: Color(0xFFD2D9EA)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (status == 'stored')
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Retry loading'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _attach(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _attach(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose photo'),
                    ),
                    if (_uploading) const LinearProgressIndicator(),
                  ],
                ],
                const SizedBox(height: 20),
                Text(
                  'Chekmi verification ID: ${detail['verification_event_id']}',
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }
}
