import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/models/audit_export.dart';

void main() {
  test('exports stable CSV and escapes audit details safely', () {
    final csv = buildAuditCsv(const [
      {
        'created_at': '2026-09-18T12:00:00Z',
        'actor_staff_number': '=A-01',
        'action': 'settled',
        'subject_type': 'ticket',
        'subject_id': 'ticket-1',
        'details': {'reason': 'Paid, checked "twice"'},
      },
    ]);

    expect(
      csv,
      startsWith('timestamp,actor,action,subject_type,subject_id,details\r\n'),
    );
    expect(csv, contains('"{""reason"":'));
    expect(csv, contains('Paid, checked'));
    expect(csv, contains(r'\""twice\""'));
    expect(csv, contains("'=A-01"));
    expect(
      auditCsvFileName(DateTime.utc(2026, 9, 18)),
      'chekmi-audit-2026-09-18.csv',
    );
  });
}
