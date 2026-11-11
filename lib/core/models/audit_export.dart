import 'dart:convert';

String buildAuditCsv(Iterable<Map<String, dynamic>> events) {
  const headers = [
    'timestamp',
    'actor',
    'action',
    'subject_type',
    'subject_id',
    'details',
  ];
  final lines = <String>[headers.join(',')];
  for (final event in events) {
    final details = event['details'];
    lines.add(
      [
        event['created_at'],
        event['actor_staff_number'],
        event['action'],
        event['subject_type'],
        event['subject_id'],
        details is Map || details is List ? jsonEncode(details) : details,
      ].map(_csvCell).join(','),
    );
  }
  return '${lines.join('\r\n')}\r\n';
}

String auditCsvFileName(DateTime createdAt) {
  final date = createdAt.toUtc().toIso8601String().substring(0, 10);
  return 'chekmi-audit-$date.csv';
}

String _csvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (text.startsWith(RegExp(r'[=+\-@]'))) {
    text = "'$text";
  }
  if (!text.contains(RegExp('[,"\\r\\n]'))) return text;
  return '"${text.replaceAll('"', '""')}"';
}
