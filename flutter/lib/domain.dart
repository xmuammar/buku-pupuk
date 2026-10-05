import 'dart:convert';

typedef Json = Map<String, dynamic>;
const ownerEmail = 'xmuammar@gmail.com';
const labels = {
  'withdraw': 'Penarikan bank',
  'purchase': 'Pembelian pupuk',
  'sale': 'Penjualan petani',
  'expense': 'Biaya operasional',
  'pay': 'Bayar distributor',
  'collect': 'Terima pelunasan',
};
Json object(dynamic v) =>
    v is Map ? v.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};
List<Json> rows(dynamic v) => v == null
    ? []
    : (v is List ? v : (v as Map).values)
          .where((e) => e != null)
          .map(object)
          .toList();
num n(Json r, String key) => (r[key] as num?) ?? 0;
String s(Json r, String key) => (r[key] as String?) ?? '';
Json emptyBook() => {
  'app': 'buku-pupuk',
  'version': 1,
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'recordCount': 0,
  'records': <Json>[],
  'members': <Json>[],
  'simulation': null,
  'finance': null,
};
Json readBook(dynamic value) {
  if (value == null) return emptyBook();
  final b = object(jsonDecode(jsonEncode(value)));
  if (b['app'] != 'buku-pupuk' || b['version'] != 1) {
    throw StateError('Format database tidak dikenal.');
  }
  b['records'] = rows(b['records']);
  b['members'] = rows(b['members']);
  if (n(b, 'recordCount') != (b['records'] as List).length) {
    throw StateError('Jumlah transaksi tidak cocok.');
  }
  validateBook(b);
  return b;
}

int cashFlow(Json r) => switch (s(r, 'type')) {
  'withdraw' || 'collect' => n(r, 'amount').toInt(),
  'sale' => n(r, 'paid').toInt(),
  'purchase' => -n(r, 'paid').toInt(),
  'expense' || 'pay' => -n(r, 'amount').toInt(),
  _ => 0,
};
String productKey(Json r) => s(r, 'product').trim().toLowerCase();

class Report {
  final List<Json> selected, ending;
  final Map<String, double> stock = {};
  final Map<String, double> sacks = {};
  final Map<String, int> remaining = {};
  int opening = 0,
      cash = 0,
      receipts = 0,
      payments = 0,
      sales = 0,
      purchases = 0,
      expenses = 0,
      cogs = 0;
  double missing = 0;
  Report(List<Json> all, {String from = '', String to = ''})
    : selected = all
          .where(
            (r) =>
                (from.isEmpty || s(r, 'date').compareTo(from) >= 0) &&
                (to.isEmpty || s(r, 'date').compareTo(to) <= 0),
          )
          .toList(),
      ending = all
          .where((r) => to.isEmpty || s(r, 'date').compareTo(to) <= 0)
          .toList() {
    for (final r in ending) {
      final flow = cashFlow(r);
      cash += flow;
      if (from.isNotEmpty && s(r, 'date').compareTo(from) < 0) opening += flow;
      final type = s(r, 'type');
      if (type == 'purchase' || type == 'sale') {
        final key = productKey(r), sign = type == 'purchase' ? 1 : -1;
        stock[key] = (stock[key] ?? 0) + sign * n(r, 'qty');
        sacks[key] =
            (sacks[key] ?? 0) +
            sign * (n(r, 'sacks') == 0 ? n(r, 'qty') / 50 : n(r, 'sacks'));
        remaining[s(r, 'id')] = n(r, 'amount').toInt() - n(r, 'paid').toInt();
      }
    }
    for (final r in ending) {
      if (['pay', 'collect'].contains(r['type'])) {
        remaining[s(r, 'ref')] =
            (remaining[s(r, 'ref')] ?? 0) - n(r, 'amount').toInt();
      }
    }
    for (final r in selected) {
      final f = cashFlow(r);
      if (f > 0) {
        receipts += f;
      } else {
        payments -= f;
      }
      switch (r['type']) {
        case 'sale':
          sales += n(r, 'amount').toInt();
        case 'purchase':
          purchases += n(r, 'amount').toInt();
        case 'expense':
          expenses += n(r, 'amount').toInt();
      }
    }
    final ordered =
        ending.where((r) => ['purchase', 'sale'].contains(r['type'])).toList()
          ..sort((a, b) {
            final d = s(a, 'date').compareTo(s(b, 'date'));
            return d != 0
                ? d
                : a['type'] == b['type']
                ? s(a, 'id').compareTo(s(b, 'id'))
                : a['type'] == 'purchase'
                ? -1
                : 1;
          });
    final lots = <String, List<List<double>>>{};
    double cost = 0;
    for (final r in ordered) {
      final batch = lots.putIfAbsent(productKey(r), () => []);
      if (r['type'] == 'purchase') {
        batch.add([n(r, 'qty').toDouble(), n(r, 'amount').toDouble()]);
        continue;
      }
      var qty = n(r, 'qty').toDouble(), saleCost = 0.0;
      while (qty > 0.000001 && batch.isNotEmpty) {
        final lot = batch.first,
            used = qty < lot[0] ? qty : lot[0],
            portion = used / lot[0] * lot[1];
        saleCost += portion;
        lot[0] -= used;
        lot[1] -= portion;
        qty -= used;
        if (lot[0] < 0.000001) batch.removeAt(0);
      }
      if (qty > 0.000001) missing += qty;
      if (from.isEmpty || s(r, 'date').compareTo(from) >= 0) cost += saleCost;
    }
    cogs = cost.round();
  }
  int get transactionTotal => receipts - payments;
  int get profit => sales - cogs - expenses;
  int outstanding(String type) => ending
      .where((r) => r['type'] == type)
      .fold(0, (sum, r) => sum + (remaining[s(r, 'id')] ?? 0));
}

void require(bool ok, String message) {
  if (!ok) throw StateError(message);
}

bool validDate(String v) {
  final d = DateTime.tryParse(v);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) &&
      d != null &&
      d.toIso8601String().substring(0, 10) == v;
}

void validateBook(Json b) {
  final records = rows(b['records']), members = rows(b['members']);
  final ids = <String>{}, niks = <String>{}, memberIds = <String>{};
  for (final m in members) {
    require(
      s(m, 'id').isNotEmpty && memberIds.add(s(m, 'id')),
      'ID anggota berulang.',
    );
    require(
      s(m, 'name').trim().isNotEmpty && s(m, 'name').length <= 200,
      'Nama anggota wajib diisi.',
    );
    final nik = s(m, 'nik');
    require(
      nik.isEmpty || RegExp(r'^\d{16}$').hasMatch(nik) && niks.add(nik),
      'NIK harus 16 digit dan unik.',
    );
  }
  for (final r in records) {
    require(
      s(r, 'id').isNotEmpty && ids.add(s(r, 'id')),
      'ID transaksi berulang.',
    );
    require(
      labels.containsKey(r['type']) &&
          validDate(s(r, 'date')) &&
          s(r, 'name').trim().isNotEmpty,
      'Periksa jenis, tanggal dan nama.',
    );
    for (final key in ['amount', 'paid', 'unit_price']) {
      final val = n(r, key);
      require(
        val.isFinite &&
            val >= 0 &&
            val == val.round() &&
            val <= 9007199254740991,
        'Nilai rupiah tidak valid.',
      );
    }
    require(
      n(r, 'amount') > 0 && n(r, 'paid') <= n(r, 'amount'),
      'Pembayaran melebihi jumlah atau jumlah nol.',
    );
    require(
      n(r, 'qty').isFinite && n(r, 'sacks').isFinite && n(r, 'sacks') >= 0,
      'Jumlah pupuk tidak valid.',
    );
    final item = ['purchase', 'sale'].contains(r['type']);
    require(
      item
          ? n(r, 'qty') > 0 && s(r, 'product').trim().isNotEmpty
          : n(r, 'qty') == 0 && n(r, 'paid') == 0,
      'Jumlah pupuk atau pembayaran awal tidak valid.',
    );
    require(
      s(r, 'receipt_data').length <= 2000000,
      'Lampiran terlalu besar (maksimal sekitar 1,5 MB).',
    );
    if (r['type'] == 'sale' && s(r, 'sale_kind').isNotEmpty) {
      require(
        ['subsidi', 'non_subsidi'].contains(r['sale_kind']),
        'Jenis penjualan tidak valid.',
      );
      if (r['sale_kind'] == 'subsidi') {
        require(
          memberIds.contains(s(r, 'member_id')),
          'Pilih anggota subsidi.',
        );
      }
    }
  }
  final map = {for (final r in records) s(r, 'id'): r};
  for (final r in records) {
    if (['pay', 'collect'].contains(r['type'])) {
      require(
        map[s(r, 'ref')]?['type'] == (r['type'] == 'pay' ? 'purchase' : 'sale'),
        'Tagihan tidak ditemukan.',
      );
    }
  }
  final report = Report(records);
  require(
    report.stock.values.every((v) => v >= -0.000001),
    'Stok tidak mencukupi.',
  );
  require(
    report.remaining.values.every((v) => v >= 0),
    'Pembayaran melebihi sisa tagihan.',
  );
}

String canonical(dynamic value) {
  if (value is num && value == value.round()) return value.round().toString();
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${canonical(value[k])}').join(',')}}';
  }
  if (value is List) return '[${value.map(canonical).join(',')}]';
  return jsonEncode(value);
}

Json applyChange(Json book, Json change) {
  final b = readBook(book),
      bucket = s(change, 'bucket'),
      key = s(change, 'key');
  require(
    ['records', 'members', 'finance', 'simulation'].contains(bucket),
    'Perubahan tidak dikenal.',
  );
  if (bucket == 'records' || bucket == 'members') {
    final list = rows(b[bucket]),
        index = list.indexWhere((r) => s(r, 'id') == key);
    final current = index < 0 ? null : list[index];
    if (canonical(current) == canonical(change['value'])) return b;
    require(
      canonical(current) == canonical(change['original']),
      'Data berubah di HP lain. Buka ulang formulir.',
    );
    if (index < 0) {
      list.add(object(change['value']));
    } else {
      list[index] = object(change['value']);
    }
    b[bucket] = list;
  } else {
    if (canonical(b[bucket]) == canonical(change['value'])) return b;
    require(
      canonical(b[bucket]) == canonical(change['original']),
      'Pengaturan berubah di HP lain.',
    );
    b[bucket] = change['value'];
  }
  b['recordCount'] = rows(b['records']).length;
  validateBook(b);
  return b;
}

Json splitProfit(
  int amount, {
  int chair = 1500,
  int treasurer = 1000,
  int supervisors = 500,
  int count = 1,
}) {
  require(
    chair >= 0 &&
        treasurer >= 0 &&
        supervisors >= 0 &&
        chair + treasurer + supervisors <= 10000 &&
        count >= 1,
    'Total honor maksimal 100%.',
  );
  final profit = amount < 0 ? 0 : amount;
  final c = profit * chair ~/ 10000,
      t = profit * treasurer ~/ 10000,
      p = profit * supervisors ~/ 10000;
  return {
    'profit': profit,
    'chair': c,
    'treasurer': t,
    'supervisors': p,
    'capital': profit - c - t - p,
    'perSupervisor': p ~/ count,
    'remainder': p % count,
  };
}
