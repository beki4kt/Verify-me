import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/widgets/entry_components.dart';

/// An interactive sample. No bank request, payment, or receipt record is made.
class InteractivePreviewScreen extends StatefulWidget {
  const InteractivePreviewScreen({super.key, this.events = false});
  final bool events;

  @override
  State<InteractivePreviewScreen> createState() =>
      _InteractivePreviewScreenState();
}

class _InteractivePreviewScreenState extends State<InteractivePreviewScreen> {
  final reference = TextEditingController();
  final amount = TextEditingController();
  String provider = 'Telebirr';
  String category = 'Door Sales';
  String scenario = 'Verified';
  bool result = false;
  String? error;

  @override
  void dispose() {
    reference.dispose();
    amount.dispose();
    super.dispose();
  }

  void _continue() {
    final value = double.tryParse(amount.text.trim());
    if (reference.text.trim().isEmpty || value == null || value <= 0) {
      setState(() => error = 'Enter a reference and a valid amount.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      error = null;
      result = true;
    });
  }

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      value,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String> onChange,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    items: items
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: (next) {
      if (next != null) onChange(next);
    },
  );

  @override
  Widget build(BuildContext context) => ChekmiEntryTheme(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(23, 18, 23, 30),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: EntryBackButton(
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                const SizedBox(height: 29),
                const EntryBrandMark(size: 48),
                const SizedBox(height: 20),
                Text(
                  widget.events ? 'Event payments' : 'Explore Chekmi',
                  style: const TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Illustrative preview · No bank check or payment is saved',
                  style: TextStyle(color: EntryColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 25),
                if (!result) ...[
                  if (widget.events) ...[
                    _label('Event'),
                    const TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Chekmi sample event',
                      ),
                    ),
                    const SizedBox(height: 17),
                    _label('Sales category'),
                    _dropdown(category, [
                      'Door Sales',
                      'Food & Drinks',
                      'Merchandise',
                      'Parking',
                      'Sponsorships',
                    ], (next) => setState(() => category = next)),
                    const SizedBox(height: 17),
                  ],
                  _label('Provider'),
                  _dropdown(provider, [
                    'Telebirr',
                    'CBE Birr',
                    'M-Pesa',
                  ], (next) => setState(() => provider = next)),
                  const SizedBox(height: 17),
                  _label('Receipt reference'),
                  TextField(
                    controller: reference,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Example: TXN-208',
                    ),
                  ),
                  const SizedBox(height: 17),
                  _label('Expected amount'),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: 'ETB 250.00'),
                  ),
                  const SizedBox(height: 22),
                  _label('Preview result'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: ['Verified', 'Pending', 'Duplicate']
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item),
                            selected: scenario == item,
                            selectedColor: EntryColors.selected,
                            backgroundColor: EntryColors.surface,
                            side: BorderSide(
                              color: scenario == item
                                  ? EntryColors.blue
                                  : EntryColors.line,
                            ),
                            onSelected: (_) => setState(() => scenario = item),
                          ),
                        )
                        .toList(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: const TextStyle(color: EntryColors.error),
                    ),
                  ],
                  const SizedBox(height: 23),
                  EntryActionButton(
                    label: 'Show sample result',
                    onPressed: _continue,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: EntryColors.surface,
                      border: Border.all(color: EntryColors.line),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              scenario == 'Verified'
                                  ? CupertinoIcons.checkmark_shield_fill
                                  : CupertinoIcons.clock_fill,
                              color: scenario == 'Verified'
                                  ? EntryColors.blue
                                  : EntryColors.orange,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Payment $scenario',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'ETB ${double.parse(amount.text.trim()).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 17),
                        _detail('Provider', provider),
                        _detail('Reference', reference.text.trim()),
                        if (widget.events) _detail('Category', category),
                        const Divider(color: EntryColors.line, height: 28),
                        Text(
                          scenario == 'Verified'
                              ? 'Business completion: automatic in this sample'
                              : 'No payment is counted or completed',
                          style: const TextStyle(color: EntryColors.muted),
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'SAMPLE ONLY · No bank response or receipt archive',
                          style: TextStyle(
                            color: EntryColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  EntryActionButton(
                    label: 'Try another',
                    onPressed: () => setState(() => result = false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: EntryColors.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
