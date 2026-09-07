// The payment dialog is where a part payment is actually entered, so its
// arithmetic and guardrails are pinned down here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pg_management/presentation/widgets/record_payment_dialog.dart';

/// Holds the value the dialog returned once it closes.
class _DialogResult {
  PaymentEntry? entry;
  bool closed = false;
}

/// Pumps a host page, opens the dialog on it, and returns the result holder.
Future<_DialogResult> _openDialog(
  WidgetTester tester, {
  required int amountDue,
  required double alreadyPaid,
}) async {
  final result = _DialogResult();

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result.entry = await showDialog<PaymentEntry>(
              context: context,
              builder: (_) => RecordPaymentDialog(
                studentName: 'Asha',
                roomNumber: '101',
                amountDue: amountDue,
                alreadyPaid: alreadyPaid,
              ),
            );
            result.closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows what is still due after earlier instalments',
      (tester) async {
    await _openDialog(tester, amountDue: 5200, alreadyPaid: 2000);

    expect(find.text('Already paid'), findsOneWidget);
    expect(find.text('₹2000'), findsOneWidget);
    expect(find.text('Still due'), findsOneWidget);
    expect(find.text('₹3200'), findsOneWidget);
  });

  testWidgets('splits an instalment between cash and UPI', (tester) async {
    final result = await _openDialog(tester, amountDue: 5000, alreadyPaid: 0);

    await tester.enterText(find.widgetWithText(TextField, 'Cash amount'), '2000');
    await tester.enterText(find.widgetWithText(TextField, 'UPI amount'), '1500');
    await tester.pump();

    expect(
      find.textContaining('Part payment — ₹1500 will still be due'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save Payment'));
    await tester.pumpAndSettle();

    expect(result.closed, isTrue);
    expect(result.entry!.cashAmount, 2000);
    expect(result.entry!.upiAmount, 1500);
    expect(result.entry!.hasUpi, isTrue);
  });

  testWidgets('the All button drops the outstanding amount into one field',
      (tester) async {
    final result = await _openDialog(tester, amountDue: 5200, alreadyPaid: 2000);

    // Two 'All' buttons — the first belongs to the cash row.
    await tester.tap(find.text('All').first);
    await tester.pump();

    expect(find.textContaining('This clears the rent in full'), findsOneWidget);

    await tester.tap(find.text('Save Payment'));
    await tester.pumpAndSettle();

    expect(result.closed, isTrue);
    expect(result.entry!.cashAmount, 3200);
    expect(result.entry!.upiAmount, 0);
  });

  testWidgets('refuses more than the outstanding balance', (tester) async {
    await _openDialog(tester, amountDue: 5000, alreadyPaid: 4000);

    await tester.enterText(find.widgetWithText(TextField, 'Cash amount'), '2000');
    await tester.tap(find.text('Save Payment'));
    await tester.pump();

    expect(find.textContaining('more than the ₹1000 still due'), findsOneWidget);
    // Still open — nothing was recorded.
    expect(find.text('Save Payment'), findsOneWidget);
  });

  testWidgets('refuses an empty payment', (tester) async {
    await _openDialog(tester, amountDue: 5000, alreadyPaid: 0);

    await tester.tap(find.text('Save Payment'));
    await tester.pump();

    expect(
      find.text('Enter a cash amount, a UPI amount, or both.'),
      findsOneWidget,
    );
  });
}
