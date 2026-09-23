import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AuditCsvExportResult { shared, copied }

class AuditCsvExporter {
  AuditCsvExporter._();

  static const _channel = MethodChannel('com.chekmi.app/audit_export');

  static Future<AuditCsvExportResult> export({
    required String fileName,
    required String csv,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('shareCsv', {
          'fileName': fileName,
          'content': csv,
        });
        return AuditCsvExportResult.shared;
      } on PlatformException {
        // Clipboard remains a usable export path on unsupported Android hosts.
      } on MissingPluginException {
        // Tests and nonstandard embedders do not register the Android channel.
      }
    }
    await Clipboard.setData(ClipboardData(text: csv));
    return AuditCsvExportResult.copied;
  }
}
