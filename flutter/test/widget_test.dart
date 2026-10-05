import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buku_pupuk/main.dart';
import 'package:buku_pupuk/domain.dart';

void main() {
  test('money input retains cursor and inserts Indonesian separators', () {
    final formatter = MoneyFormatter();
    final value = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '9750000',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );
    expect(value.text, '9.750.000');
    expect(value.selection.baseOffset, 9);
  });
  testWidgets('purchase form calculates kg and amount from sacks and price', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Editor(type: 'purchase', book: emptyBook()),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama / pihak terkait'),
      'Distributor',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Produk pupuk'),
      'Urea',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Jumlah sak (1 sak = 50 kg)'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Harga per sak'),
      '20000',
    );
    await tester.pump();
    final qty = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Jumlah kg'),
    );
    final amount = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Jumlah rupiah'),
    );
    expect(qty.controller!.text, '500.0');
    expect(amount.controller!.text, '200.000');
  });
}
