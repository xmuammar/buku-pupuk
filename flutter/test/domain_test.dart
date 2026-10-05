import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:buku_pupuk/domain.dart';

Json record(
  String id,
  String type, {
  int amount = 100,
  int paid = 0,
  double qty = 0,
  String ref = '',
  String date = '2026-10-01',
}) => {
  'id': id,
  'type': type,
  'date': date,
  'name': 'Uji',
  'product': qty > 0 ? 'Urea' : '',
  'qty': qty,
  'sacks': qty / 50,
  'unit_price': 0,
  'amount': amount,
  'paid': paid,
  'ref': ref,
  'note': '',
};
Json book(List<Json> r) => {
  ...emptyBook(),
  'records': r,
  'recordCount': r.length,
};
void main() {
  test('reads existing repository fixture', () {
    final b = readBook(
      jsonDecode(File('test/fixtures/legacy.json').readAsStringSync()),
    );
    final report = Report(rows(b['records']));
    expect(report.cash, 280000);
    expect(report.stock['urea'], 500);
  });
  test('cash total does not count unpaid purchase twice', () {
    final r = Report([
      record('w', 'withdraw', amount: 10000000),
      record('p', 'purchase', amount: 10000000, qty: 500),
      record('e', 'expense', amount: 250000),
    ]);
    expect(r.transactionTotal, 9750000);
    expect(r.outstanding('purchase'), 10000000);
  });
  test('repayments are cash movements, not new profit', () {
    final r = Report([
      record('p', 'purchase', amount: 1000, qty: 100),
      record('s', 'sale', amount: 1500, paid: 500, qty: 50),
      record('pay', 'pay', amount: 200, ref: 'p'),
      record('collect', 'collect', amount: 300, ref: 's'),
    ]);
    expect(r.profit, 1000);
    expect(r.cash, 600);
    expect(r.outstanding('purchase'), 800);
    expect(r.outstanding('sale'), 700);
  });
  test('FIFO consumes pre-period purchases', () {
    final r = Report([
      record('p', 'purchase', amount: 1000, qty: 100, date: '2026-09-01'),
      record('s', 'sale', amount: 1200, qty: 50),
    ], from: '2026-10-01');
    expect(r.cogs, 500);
    expect(r.profit, 700);
  });
  test('stock and payment validation', () {
    expect(
      () => readBook(book([record('s', 'sale', qty: 50)])),
      throwsStateError,
    );
    expect(
      () => readBook(
        book([
          record('p', 'purchase', qty: 50),
          record('pay', 'pay', amount: 101, ref: 'p'),
        ]),
      ),
      throwsStateError,
    );
  });
  test('editing rejects concurrent changes and retry is idempotent', () {
    final old = record('w', 'withdraw'),
        b = book([old]),
        changed = {...old, 'amount': 200};
    final c = {
      'bucket': 'records',
      'key': 'w',
      'original': old,
      'value': changed,
    };
    final next = applyChange(b, c);
    expect(n(rows(next['records']).first, 'amount'), 200);
    expect(
      () => applyChange(
        book([
          {...old, 'amount': 300},
        ]),
        c,
      ),
      throwsStateError,
    );
    expect(applyChange(next, c), next);
  });
  test('profit split conserves rupiah', () {
    final shares = splitProfit(1000001, count: 3);
    expect(shares['chair'], 150000);
    expect(shares['treasurer'], 100000);
    expect(shares['supervisors'], 50000);
    expect(shares['capital'], 700001);
    expect(shares['perSupervisor'], 16666);
    expect(shares['remainder'], 2);
    expect(splitProfit(-100)['capital'], 0);
    expect(
      () => splitProfit(100, chair: 9000, treasurer: 2000),
      throwsStateError,
    );
  });
  test('invalid calendar date and duplicate NIK', () {
    expect(validDate('2026-02-30'), false);
    expect(
      () => readBook({
        ...emptyBook(),
        'members': [
          {'id': '1', 'name': 'A', 'nik': '1234567890123456'},
          {'id': '2', 'name': 'B', 'nik': '1234567890123456'},
        ],
      }),
      throwsStateError,
    );
  });
}
