import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buku_pupuk/domain.dart';
import 'package:buku_pupuk/exports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Json book;
  setUp(
    () => book = readBook(
      jsonDecode(File('test/fixtures/legacy.json').readAsStringSync()),
    ),
  );
  test('Excel totals and monetary cells remain numeric', () async {
    final bytes = await buildExport(book, 'xlsx');
    final excel = Excel.decodeBytes(bytes);
    expect(
      excel.tables.keys,
      containsAll(['Ringkasan', 'Transaksi', 'Stok', 'Tagihan', 'Anggota']),
    );
    final cash = excel['Ringkasan'].cell(CellIndex.indexByString('B6')).value;
    expect(cash, IntCellValue(280000));
    expect(
      excel['Transaksi'].cell(CellIndex.indexByString('H2')).value,
      IntCellValue(500000),
    );
    File('/tmp/buku-test-report.xlsx').writeAsBytesSync(bytes);
  });
  test('PDF export generates embedded-font report', () async {
    final bytes = await buildExport(book, 'pdf');
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));
    File('/tmp/buku-test-report.pdf').writeAsBytesSync(bytes);
  });
  test(
    'JSON preserves settings, attachments and durable queue archive',
    () async {
      book['pendingChanges'] = [
        {
          'bucket': 'records',
          'key': 'new',
          'value': {'amount': 10},
        },
      ];
      final result = jsonDecode(utf8.decode(await buildExport(book, 'json')));
      expect(result['records'], book['records']);
      expect(result['pendingChanges'], book['pendingChanges']);
      expect(result['recordCount'], 3);
    },
  );
  test('CSV escapes commas and quotes in transaction names', () async {
    (book['records'] as List).first['name'] = 'Nama, "Uji"';
    final bytes = await buildExport(book, 'csv');
    final csv = utf8.decode(bytes);
    expect(csv, contains('"Nama, ""Uji"""'));
    expect(bytes.take(3), [239, 187, 191]);
  });
}
