# Business payment workflow

The staff workspace captures bank payment receipts for shops, service providers,
restaurants, and other businesses. Staff choose a payment provider, scan the
receipt or enter its bank transaction reference, and enter the amount due.

Payments can optionally include an invoice number, order number, customer
reference, table number, or another note such as a booking reference. When left
blank, the bank transaction reference identifies the payment. This context is
shown in the staff payment list, cashier review and history, and administrator
ledger. It links a receipt to business activity; it does not validate or generate
an invoice.

Activity shows verified payment volume and receipt history. Staff tips and
withdrawal requests are in a collapsed section for teams that use them. The
existing accounting rule still classifies payment amounts above the amount due
as staff tips; the submission form states this. Refunds, customer credits, and
configurable overpayment policies are not implemented by this UI change.

Compatibility: stored role identifiers and permissions remain unchanged. New
business references use a typed prefix in the existing text `table_number`
column. Unprefixed older values continue to display as table references. No
database migration is needed with the currently deployed verification API.

Validation:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --dart-define=CHEKMI_IPHONE_UI=true test/payment_context_test.dart test/iphone_layout_test.dart test/iphone_ui_test.dart
```

Source changes require a new IPA build and installation before appearing in an
already installed native iPhone app.
