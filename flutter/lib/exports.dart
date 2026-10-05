import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:excel/excel.dart';

import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'domain.dart';

final rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);
String money(num value) => rupiah.format(value);
List<List<String>> reportRows(Report r) => [
  [
    'Jenis',
    'Tanggal',
    'Nama',
    'Produk',
    'Kg',
    'Sak',
    'Harga/sak',
    'Jumlah',
    'Dibayar',
    'Arus kas',
    'Catatan',
  ],
  for (final t in r.selected)
    [
      labels[s(t, 'type')] ?? '',
      s(t, 'date'),
      s(t, 'name'),
      s(t, 'product'),
      '${n(t, 'qty')}',
      '${n(t, 'sacks')}',
      money(n(t, 'unit_price')),
      money(n(t, 'amount')),
      money(n(t, 'paid')),
      money(cashFlow(t)),
      s(t, 'note'),
    ],
];
List<List<String>> summaryRows(Report r) => [
  ['Keterangan', 'Nilai'],
  ['Saldo awal', money(r.opening)],
  ['Penerimaan', money(r.receipts)],
  ['Pengeluaran', money(r.payments)],
  ['Total transaksi (arus kas bersih)', money(r.transactionTotal)],
  ['Saldo kas', money(r.cash)],
  ['Pembelian', money(r.purchases)],
  ['Penjualan', money(r.sales)],
  ['Biaya operasional', money(r.expenses)],
  ['Utang', money(r.outstanding('purchase'))],
  ['Piutang', money(r.outstanding('sale'))],
  ['HPP FIFO', money(r.cogs)],
  ['Laba', r.missing > 0 ? 'Riwayat stok tidak lengkap' : money(r.profit)],
  ['Bendahara', 'Muammar, SST, M.Kom'],
];
Future<Uint8List> buildExport(
  Json book,
  String kind, {
  String from = '',
  String to = '',
}) async {
  final report = Report(rows(book['records']), from: from, to: to);
  final stock = [
    ['Produk', 'Kg', 'Sak'],
    for (final e in report.stock.entries)
      [e.key, '${e.value}', '${report.sacks[e.key]}'],
  ];
  final bills = [
    ['Jenis', 'Nama', 'Tanggal', 'Jumlah', 'Sisa'],
    for (final r in report.ending.where(
      (r) => ['purchase', 'sale'].contains(r['type']),
    ))
      [
        labels[s(r, 'type')]!,
        s(r, 'name'),
        s(r, 'date'),
        money(n(r, 'amount')),
        money(report.remaining[s(r, 'id')] ?? 0),
      ],
  ];
  Uint8List bytes;
  if (kind == 'json') {
    bytes = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          ...book,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }),
      ),
    );
  } else if (kind == 'csv') {
    bytes = Uint8List.fromList(
      utf8.encode(
        '\uFEFF${reportRows(report).map((row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',')).join('\r\n')}',
      ),
    );
  } else if (kind == 'xlsx') {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Ringkasan');
    for (final entry in {
      'Ringkasan': summaryRows(report),
      'Transaksi': reportRows(report),
      'Stok': stock,
      'Tagihan': bills,
      'Anggota': [
        ['Nama', 'NIK', 'Kelompok', 'Alamat'],
        for (final m in rows(book['members']))
          [s(m, 'name'), s(m, 'nik'), s(m, 'farmer_group'), s(m, 'address')],
      ],
    }.entries) {
      for (final row in entry.value) {
        excel[entry.key].appendRow(row.map((v) => TextCellValue(v)).toList());
      }
    }
    void number(
      String sheet,
      int row,
      int column,
      num value, {
      bool currency = false,
    }) {
      final cell = excel[sheet].cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      );
      cell.value = value is int
          ? IntCellValue(value)
          : DoubleCellValue(value.toDouble());
      cell.cellStyle = CellStyle(
        numberFormat: NumFormat.custom(
          formatCode: currency ? '"Rp "#,##0' : '0.##',
        ),
      );
    }

    for (var i = 0; i < report.selected.length; i++) {
      final r = report.selected[i];
      for (final e in {
        4: n(r, 'qty'),
        5: n(r, 'sacks'),
        6: n(r, 'unit_price'),
        7: n(r, 'amount'),
        8: n(r, 'paid'),
        9: cashFlow(r),
      }.entries) {
        number('Transaksi', i + 1, e.key, e.value, currency: e.key >= 6);
      }
    }
    final totals = [
      report.opening,
      report.receipts,
      report.payments,
      report.transactionTotal,
      report.cash,
      report.purchases,
      report.sales,
      report.expenses,
      report.outstanding('purchase'),
      report.outstanding('sale'),
      report.cogs,
    ];
    for (var i = 0; i < totals.length; i++) {
      number('Ringkasan', i + 1, 1, totals[i], currency: true);
    }
    if (report.missing < 0.000001) {
      number('Ringkasan', 12, 1, report.profit, currency: true);
    }
    var i = 0;
    for (final e in report.stock.entries) {
      number('Stok', i + 1, 1, e.value);
      number('Stok', i + 1, 2, report.sacks[e.key] ?? 0);
      i++;
    }
    final invoices = report.ending
        .where((r) => ['purchase', 'sale'].contains(r['type']))
        .toList();
    for (var i = 0; i < invoices.length; i++) {
      final r = invoices[i];
      number('Tagihan', i + 1, 3, n(r, 'amount'), currency: true);
      number(
        'Tagihan',
        i + 1,
        4,
        report.remaining[s(r, 'id')] ?? 0,
        currency: true,
      );
    }
    for (final sheet in excel.tables.values) {
      for (var c = 0; c < sheet.maxColumns; c++) {
        sheet.setColumnWidth(c, c == 0 ? 30 : 22);
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#176B45'),
          fontColorHex: ExcelColor.white,
        );
      }
    }
    bytes = Uint8List.fromList(excel.encode()!);
  } else {
    final regular = pw.Font.ttf(
          await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
        ),
        bold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
        );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    for (final section in {
      'Ringkasan': summaryRows(report),
      'Rincian transaksi': reportRows(report),
      'Stok pupuk': stock,
      'Utang dan piutang': bills,
    }.entries) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          maxPages: 1000,
          build: (c) => [
            pw.Text(
              'BUKU PUPUK',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Laporan transaksi usaha pupuk desa • ${from.isEmpty && to.isEmpty ? 'Semua transaksi' : '$from — $to'}',
            ),
            pw.SizedBox(height: 12),
            pw.Text(section.key),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              data: section.value,
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ],
          footer: (c) => pw.Text(
            'Bendahara: Muammar, SST, M.Kom • Halaman ${c.pageNumber}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      );
    }
    bytes = await doc.save();
  }
  return bytes;
}

Future<void> exportBook(
  Json book,
  String kind, {
  String from = '',
  String to = '',
}) async {
  final bytes = await buildExport(book, kind, from: from, to: to);
  final filename =
      'Buku-Pupuk-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.$kind';
  if (kind == 'pdf') {
    await Printing.sharePdf(bytes: bytes, filename: filename);
    return;
  }
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: 'Cadangan Buku Pupuk'),
  );
}
