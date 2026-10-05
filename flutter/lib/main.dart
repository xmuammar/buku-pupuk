import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:file_selector/file_selector.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import 'domain.dart';
import 'store.dart';
import 'exports.dart';
import 'design.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyC1HPfGJcozHdxQvT1N2K7aeZkrb2cQSt0',
        appId: '1:558192902964:android:f14f184db4ffe6922fdb61',
        messagingSenderId: '558192902964',
        projectId: 'buku-pupuk-desa-kabat',
        databaseURL:
            'https://buku-pupuk-desa-kabat-default-rtdb.asia-southeast1.firebasedatabase.app',
        storageBucket: 'buku-pupuk-desa-kabat.firebasestorage.app',
      ),
    );
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    runApp(const BookApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Firebase belum dapat disiapkan: $e')),
        ),
      ),
    );
  }
}

class BookApp extends StatelessWidget {
  const BookApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Buku Pupuk',
    debugShowCheckedModeBanner: false,
    theme: bookTheme(),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, state) {
        if (state.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.data == null) return const Login();
        if (state.data!.email != ownerEmail) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: FirebaseAuth.instance.signOut,
                child: const Text('Akun tidak diizinkan. Keluar'),
              ),
            ),
          );
        }
        return Home(key: ValueKey(state.data!.uid));
      },
    ),
  );
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final password = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> action(String mode) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (mode == 'reset') {
        await auth.sendPasswordResetEmail(email: ownerEmail);
        error = 'Tautan reset dikirim ke $ownerEmail.';
      } else if (mode == 'register') {
        await auth.createUserWithEmailAndPassword(
          email: ownerEmail,
          password: password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: ownerEmail,
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      error = '${e.message}';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [green, Color(0xff104F35)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      size: 54,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Buku Pupuk',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pencatatan usaha pupuk desa',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Masuk ke akun usaha',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xffE8F1E7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        color: green,
                        size: 19,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ownerEmail,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  onSubmitted: (_) => busy ? null : action('login'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(error!),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : () => action('login'),
                  child: Text(busy ? 'Memproses…' : 'Masuk'),
                ),
                TextButton(
                  onPressed: busy ? null : () => action('register'),
                  child: const Text('Buat akun pertama'),
                ),
                TextButton(
                  onPressed: busy ? null : () => action('reset'),
                  child: const Text('Lupa kata sandi'),
                ),
                const Copyright(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class Copyright extends StatelessWidget {
  const Copyright({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      '© 2026 · Hak cipta aplikasi milik Muammar, SST, M.Kom',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11),
    ),
  );
}

class Home extends StatefulWidget {
  final BookStore? initialStore;
  const Home({super.key, this.initialStore});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  BookStore? store;
  int tab = 0;
  String page = 'Ringkasan', search = '', from = '', to = '';
  bool locked = false;
  @override
  void initState() {
    super.initState();
    if (widget.initialStore != null) {
      store = widget.initialStore;
      store!.addListener(refresh);
    } else {
      init();
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final value = BookStore(prefs);
    store = value;
    value.addListener(refresh);
    await value.start();
    if (mounted) setState(() {});
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store?.removeListener(refresh);
    if (widget.initialStore == null) store?.dispose();
    super.dispose();
  }

  Future<void> guarded(Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> edit(String type, {Json? original, bool member = false}) async {
    final b = store!.view;
    final value = await Navigator.of(context).push<Json>(
      MaterialPageRoute(
        builder: (_) =>
            Editor(type: type, book: b, original: original, member: member),
      ),
    );
    if (value != null) {
      await guarded(
        () => store!.save(
          member ? 'members' : 'records',
          s(value, 'id'),
          value,
          original,
        ),
      );
    }
  }

  void navigate(String destination) {
    setState(() {
      page = destination;
      tab = [
        'Ringkasan',
        'Pembelian',
        'Penjualan',
        'Anggota',
      ].indexOf(destination);
      if (tab < 0) tab = 4;
      search = '';
    });
  }

  Widget tile(String title, Object value) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            '$value',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: ink,
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> dateFilter(bool start) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (selected != null) {
      setState(() {
        if (start) {
          from = selected.toIso8601String().substring(0, 10);
        } else {
          to = selected.toIso8601String().substring(0, 10);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = store;
    if (st == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buku Pupuk terkunci')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => guarded(() async {
                  final auth = LocalAuthentication();
                  if (await auth.authenticate(
                        localizedReason: 'Buka Buku Pupuk',
                        options: const AuthenticationOptions(
                          biometricOnly: true,
                        ),
                      ) &&
                      mounted) {
                    setState(() => locked = false);
                  }
                }),
                child: const Text('Buka dengan sidik jari'),
              ),
              TextButton(
                onPressed: st.pending.isEmpty
                    ? FirebaseAuth.instance.signOut
                    : null,
                child: const Text('Keluar dan masuk dengan kata sandi'),
              ),
            ],
          ),
        ),
      );
    }
    final b = {...st.view, 'pendingChanges': st.pending},
        all = rows(b['records']),
        report = Report(
          all,
          from: page == 'Laporan' ? from : '',
          to: page == 'Laporan' ? to : '',
        );
    Widget content;
    if (!st.ready) {
      content = const Center(child: CircularProgressIndicator());
    } else if (page == 'Anggota') {
      final members =
          rows(b['members'])
              .where(
                (m) =>
                    s(m, 'name').toLowerCase().contains(search.toLowerCase()) ||
                    s(m, 'nik').contains(search),
              )
              .toList()
            ..sort((a, b) => s(a, 'name').compareTo(s(b, 'name')));
      content = ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
        itemCount: members.length,
        itemBuilder: (c, i) {
          final m = members[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xffE4EEE3),
                foregroundColor: green,
                child: Text(
                  s(m, 'name').isEmpty
                      ? '?'
                      : s(m, 'name').substring(0, 1).toUpperCase(),
                ),
              ),
              title: Text(s(m, 'name')),
              subtitle: Text(
                '${s(m, 'nik')}\n${s(m, 'farmer_group')} • ${s(m, 'address')}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => edit('', member: true, original: m),
            ),
          );
        },
      );
    } else if (['Pembelian', 'Penjualan', 'Buku kas'].contains(page)) {
      final records =
          all
              .where(
                (r) =>
                    (page == 'Buku kas' ||
                        r['type'] ==
                            (page == 'Pembelian' ? 'purchase' : 'sale')) &&
                    ('${s(r, 'name')} ${s(r, 'product')}')
                        .toLowerCase()
                        .contains(search.toLowerCase()),
              )
              .toList()
            ..sort((a, b) => s(b, 'date').compareTo(s(a, 'date')));
      content = records.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada catatan',
              description:
                  'Tekan Catat transaksi untuk menambahkan catatan usaha.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
              itemCount: records.length,
              itemBuilder: (c, i) => TransactionCard(
                record: records[i],
                onTap: () => edit(s(records[i], 'type'), original: records[i]),
              ),
            );
    } else if (page == 'Stok pupuk') {
      content = ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const SectionTitle('Persediaan pupuk'),
          for (final e in report.stock.entries)
            tile(e.key, '${e.value} kg • ${report.sacks[e.key]} sak'),
          tile('Utang distributor', money(report.outstanding('purchase'))),
          tile('Piutang petani', money(report.outstanding('sale'))),
          for (final r in report.ending.where(
            (r) =>
                ['purchase', 'sale'].contains(r['type']) &&
                (report.remaining[s(r, 'id')] ?? 0) > 0,
          ))
            Card(
              child: ListTile(
                title: Text(s(r, 'name')),
                subtitle: Text('Sisa ${money(report.remaining[s(r, 'id')]!)}'),
                trailing: const Icon(Icons.payments),
                onTap: () => edit(r['type'] == 'purchase' ? 'pay' : 'collect'),
              ),
            ),
        ],
      );
    } else if (page == 'Keuangan') {
      content = FinancePanel(book: b, store: st);
    } else if (page == 'Simulasi') {
      content = SimulationPanel(book: b, store: st);
    } else if (page == 'Laporan' || page == 'Cadangan') {
      content = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (page == 'Laporan')
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => dateFilter(true),
                  child: Text(from.isEmpty ? 'Tanggal awal' : from),
                ),
                OutlinedButton(
                  onPressed: () => dateFilter(false),
                  child: Text(to.isEmpty ? 'Tanggal akhir' : to),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    from = '';
                    to = '';
                  }),
                  child: const Text('Semua tanggal'),
                ),
              ],
            ),
          for (final row in summaryRows(report).skip(1)) tile(row[0], row[1]),
          for (final kind
              in page == 'Cadangan'
                  ? ['json', 'xlsx', 'pdf']
                  : ['xlsx', 'pdf', 'csv'])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                onPressed: () => guarded(
                  () => exportBook(
                    b,
                    kind,
                    from: page == 'Cadangan' ? '' : from,
                    to: page == 'Cadangan' ? '' : to,
                  ),
                ),
                icon: const Icon(Icons.download),
                label: Text('Simpan ${kind.toUpperCase()}'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Pilih Google Drive pada lembar berbagi / pemilih tujuan. Cadangan ini dibuat saat tombol ditekan. Firebase menyinkronkan data secara otomatis.',
            ),
          ),
        ],
      );
    } else if (page == 'Lainnya') {
      content = MoreMenu(onNavigate: navigate);
    } else {
      content = Dashboard(
        report: report,
        records: all,
        onEdit: (type) => edit(type),
        onNavigate: navigate,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              page == 'Ringkasan' ? 'Buku Pupuk' : page,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -.6,
              ),
            ),
            const Text(
              'BUMDes · Desa Kabat',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Kunci') {
                setState(() => locked = true);
              } else if (value == 'Keluar') {
                if (st.pending.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sinkronkan perubahan lokal sebelum keluar.',
                      ),
                    ),
                  );
                } else {
                  FirebaseAuth.instance.signOut();
                }
              } else {
                navigate(value);
              }
            },
            itemBuilder: (_) => [
              for (final p in [
                'Stok pupuk',
                'Simulasi',
                'Buku kas',
                'Keuangan',
                'Laporan',
                'Cadangan',
                'Kunci',
                'Keluar',
              ])
                PopupMenuItem(value: p, child: Text(p)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SyncStrip(
            connected: st.connected,
            sending: st.sending,
            pending: st.pending.length,
            onSync: () => guarded(st.flush),
          ),
          if (st.error != null)
            Material(
              color: Colors.red.shade50,
              child: ListTile(
                title: Text(st.error!),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Perubahan belum tersinkron'),
                    content: const Text(
                      'Data lokal tetap disimpan. Coba sinkronkan kembali. Untuk konflik, simpan cadangan JSON dahulu, lalu buang antrean dan masukkan ulang perubahan berdasarkan data terbaru.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Tutup'),
                      ),
                      TextButton(
                        onPressed: st.sending
                            ? null
                            : () => guarded(() async {
                                await exportBook(st.view, 'json');
                              }),
                        child: const Text('Cadangkan'),
                      ),
                      TextButton(
                        onPressed: st.sending
                            ? null
                            : () => guarded(() async {
                                await st.discardConflict();
                                if (c.mounted) Navigator.pop(c);
                              }),
                        child: const Text('Buang antrean'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (['Anggota', 'Pembelian', 'Penjualan', 'Buku kas'].contains(page))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Cari',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
          Expanded(child: content),
        ],
      ),
      floatingActionButton:
          st.ready &&
              ['Anggota', 'Pembelian', 'Penjualan', 'Buku kas'].contains(page)
          ? FloatingActionButton.extended(
              onPressed: () => edit(
                page == 'Pembelian'
                    ? 'purchase'
                    : page == 'Penjualan'
                    ? 'sale'
                    : 'expense',
                member: page == 'Anggota',
              ),
              icon: const Icon(Icons.add),
              label: Text(
                page == 'Anggota' ? 'Tambah anggota' : 'Catat transaksi',
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() {
          tab = i;
          page = [
            'Ringkasan',
            'Pembelian',
            'Penjualan',
            'Anggota',
            'Lainnya',
          ][i];
          search = '';
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Ringkasan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Pembelian',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'Penjualan',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Anggota',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}

class MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    final number = int.tryParse(digits);
    if (number == null || number > 9007199254740991) return oldValue;
    final text = NumberFormatDecimal.format(number);
    final right = newValue.text
        .substring(newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var offset = text.length, count = 0;
    while (offset > 0 && count < right) {
      offset--;
      if (RegExp(r'[0-9]').hasMatch(text[offset])) count++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class NumberFormatDecimal {
  static String format(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => '.',
  );
}

class Editor extends StatefulWidget {
  final String type;
  final Json book;
  final Json? original;
  final bool member;
  const Editor({
    super.key,
    required this.type,
    required this.book,
    this.original,
    this.member = false,
  });
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final fields = <String, TextEditingController>{};
  late Json value;
  String? error;
  @override
  void initState() {
    super.initState();
    value = {...?widget.original};
    value.putIfAbsent('id', () => const Uuid().v4());
    value.putIfAbsent('type', () => widget.type);
    value.putIfAbsent(
      'date',
      () => DateTime.now().toIso8601String().substring(0, 10),
    );
    value.putIfAbsent(
      'sale_kind',
      () => widget.type == 'sale' ? 'non_subsidi' : '',
    );
    if (widget.type == 'sale' &&
        !['subsidi', 'non_subsidi'].contains(value['sale_kind'])) {
      value['sale_kind'] = 'non_subsidi';
    }
    for (final key in [
      'name',
      'date',
      'product',
      'qty',
      'sacks',
      'unit_price',
      'amount',
      'paid',
      'note',
      'nik',
      'farmer_group',
      'address',
    ]) {
      final moneyField = ['unit_price', 'amount', 'paid'].contains(key);
      fields[key] = TextEditingController(
        text: moneyField
            ? NumberFormatDecimal.format(n(value, key).toInt())
            : '${value[key] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    String key,
    String label, {
    bool amount = false,
    bool decimal = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: fields[key],
      keyboardType: amount || decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: amount ? [MoneyFormatter()] : null,
      readOnly: key == 'date',
      onTap: key == 'date'
          ? () async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate:
                    DateTime.tryParse(fields[key]!.text) ?? DateTime.now(),
              );
              if (selected != null) {
                fields[key]!.text = selected.toIso8601String().substring(0, 10);
              }
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: amount ? 'Rp ' : null,
        suffixIcon: key == 'date'
            ? const Icon(Icons.calendar_month_outlined)
            : null,
      ),
      onChanged: (_) {
        if (key == 'sacks') {
          final sacks = double.tryParse(fields[key]!.text.replaceAll(',', '.'));
          if (sacks != null) fields['qty']!.text = '${sacks * 50}';
        }
        if (['sacks', 'unit_price'].contains(key)) {
          final sacks =
                  double.tryParse(fields['sacks']!.text.replaceAll(',', '.')) ??
                  0,
              price =
                  int.tryParse(
                    fields['unit_price']!.text.replaceAll('.', ''),
                  ) ??
                  0;
          if (sacks > 0 && price > 0) {
            fields['amount']!.text = NumberFormatDecimal.format(
              (sacks * price).round(),
            );
          }
        }
      },
    ),
  );
  void submit() {
    try {
      final result = {...value};
      if (widget.member) {
        for (final k in ['name', 'nik', 'farmer_group', 'address']) {
          result[k] = fields[k]!.text.trim();
        }
        result['updated_at'] = DateTime.now().toUtc().toIso8601String();
      } else {
        for (final k in ['name', 'date', 'product', 'note']) {
          result[k] = fields[k]!.text.trim();
        }
        for (final k in ['amount', 'paid', 'unit_price']) {
          result[k] = int.tryParse(fields[k]!.text.replaceAll('.', '')) ?? 0;
        }
        for (final k in ['qty', 'sacks']) {
          result[k] =
              double.tryParse(fields[k]!.text.replaceAll(',', '.')) ?? 0;
        }
        result.putIfAbsent('ref', () => '');
        result.putIfAbsent('receipt_name', () => '');
        result.putIfAbsent('receipt_data', () => '');
        if (widget.type == 'sale' && result['sale_kind'] == 'subsidi') {
          final m = rows(
            widget.book['members'],
          ).firstWhere((m) => m['id'] == result['member_id'], orElse: () => {});
          result['name'] = s(m, 'name');
        }
        if (!['purchase', 'sale'].contains(widget.type)) {
          result['qty'] = 0;
          result['sacks'] = 0;
          result['paid'] = 0;
        }
      }
      applyChange(widget.book, {
        'bucket': widget.member ? 'members' : 'records',
        'key': result['id'],
        'original': widget.original,
        'value': result,
      });
      Navigator.pop(context, result);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ['purchase', 'sale'].contains(widget.type),
        bills = rows(widget.book['records'])
            .where(
              (r) => r['type'] == (widget.type == 'pay' ? 'purchase' : 'sale'),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.member
              ? widget.original == null
                    ? 'Anggota baru'
                    : 'Edit anggota'
              : '${widget.original == null ? 'Catat' : 'Edit'} ${labels[widget.type] ?? ''}',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              widget.member
                  ? 'Simpan identitas dan kelompok tani anggota.'
                  : item
                  ? 'Jumlah dan harga per sak membantu menghitung total transaksi.'
                  : 'Catat pergerakan kas usaha dengan jelas.',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ),
          input(
            'name',
            widget.member ? 'Nama anggota' : 'Nama / pihak terkait',
          ),
          if (widget.member) ...[
            input('nik', 'NIK (opsional, 16 digit)'),
            input('farmer_group', 'Kelompok tani'),
            input('address', 'Alamat'),
          ] else ...[
            input('date', 'Tanggal YYYY-MM-DD'),
            if (widget.type == 'sale') ...[
              DropdownButtonFormField<String>(
                initialValue: s(value, 'sale_kind'),
                decoration: const InputDecoration(labelText: 'Jenis penjualan'),
                items: const [
                  DropdownMenuItem(value: 'subsidi', child: Text('Subsidi')),
                  DropdownMenuItem(
                    value: 'non_subsidi',
                    child: Text('Non subsidi'),
                  ),
                ],
                onChanged: (v) => setState(() => value['sale_kind'] = v),
              ),
              const SizedBox(height: 12),
              if (value['sale_kind'] == 'subsidi')
                DropdownButtonFormField<String>(
                  initialValue: s(value, 'member_id').isEmpty
                      ? null
                      : s(value, 'member_id'),
                  decoration: const InputDecoration(labelText: 'Anggota'),
                  items: [
                    for (final m in rows(widget.book['members']))
                      DropdownMenuItem(
                        value: s(m, 'id'),
                        child: Text(s(m, 'name')),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    value['member_id'] = v;
                    final member = rows(
                      widget.book['members'],
                    ).firstWhere((m) => m['id'] == v, orElse: () => {});
                    fields['name']!.text = s(member, 'name');
                  }),
                ),
              const SizedBox(height: 12),
            ],
            if (item) ...[
              input('product', 'Produk pupuk'),
              input('sacks', 'Jumlah sak (1 sak = 50 kg)', decimal: true),
              input('qty', 'Jumlah kg', decimal: true),
              input('unit_price', 'Harga per sak', amount: true),
            ],
            if (['pay', 'collect'].contains(widget.type)) ...[
              DropdownButtonFormField<String>(
                initialValue: s(value, 'ref').isEmpty ? null : s(value, 'ref'),
                decoration: const InputDecoration(labelText: 'Tagihan asal'),
                items: [
                  for (final r in bills)
                    DropdownMenuItem(
                      value: s(r, 'id'),
                      child: Text('${s(r, 'name')} • ${s(r, 'date')}'),
                    ),
                ],
                onChanged: (v) => value['ref'] = v,
              ),
              const SizedBox(height: 12),
            ],
            input('amount', 'Jumlah rupiah', amount: true),
            if (item) input('paid', 'Pembayaran awal', amount: true),
            if (widget.type == 'expense')
              input('product', 'Produk terkait (opsional)'),
            input('note', 'Catatan'),
            if (s(value, 'receipt_name').isNotEmpty)
              Text('Lampiran: ${s(value, 'receipt_name')}'),
            OutlinedButton.icon(
              onPressed: () async {
                final file = await openFile(
                  acceptedTypeGroups: [
                    const XTypeGroup(
                      label: 'Kwitansi',
                      extensions: ['jpg', 'jpeg', 'png', 'pdf'],
                    ),
                  ],
                );
                if (file == null) return;
                final bytes = await file.readAsBytes();
                if (bytes.length > 1500000) {
                  setState(() => error = 'Lampiran maksimal 1,5 MB.');
                  return;
                }
                setState(() {
                  value['receipt_name'] = file.name;
                  value['receipt_data'] =
                      'data:${file.name.toLowerCase().endsWith('.pdf')
                          ? 'application/pdf'
                          : file.name.toLowerCase().endsWith('.png')
                          ? 'image/png'
                          : 'image/jpeg'};base64,${base64Encode(bytes)}';
                });
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('Lampirkan kwitansi'),
            ),
            if (s(value, 'receipt_data').isNotEmpty)
              OutlinedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (c) {
                    final data = s(value, 'receipt_data');
                    if (data.startsWith('data:image/')) {
                      return Dialog(
                        child: InteractiveViewer(
                          child: Image.memory(
                            base64Decode(data.split(',').last),
                          ),
                        ),
                      );
                    }
                    return AlertDialog(
                      title: Text(s(value, 'receipt_name')),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [
                                  XFile.fromData(
                                    base64Decode(data.split(',').last),
                                    name: s(value, 'receipt_name'),
                                    mimeType: 'application/pdf',
                                  ),
                                ],
                                fileNameOverrides: [s(value, 'receipt_name')],
                              ),
                            );
                          },
                          child: const Text('Simpan PDF'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Tutup'),
                        ),
                      ],
                    );
                  },
                ),
                child: const Text('Lihat kwitansi'),
              ),
          ],
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: submit, child: const Text('Simpan')),
        ],
      ),
    );
  }
}

class FinancePanel extends StatefulWidget {
  final Json book;
  final BookStore store;
  const FinancePanel({super.key, required this.book, required this.store});
  @override
  State<FinancePanel> createState() => _FinancePanelState();
}

class _FinancePanelState extends State<FinancePanel> {
  final fields = <String, TextEditingController>{};
  dynamic original;
  bool manual = false;
  String? message;
  final titles = {
    'profit': 'Laba manual (rupiah)',
    'chairPercent': 'Ketua (%)',
    'treasurerPercent': 'Bendahara (%)',
    'supervisorPercent': 'Seluruh pengawas (%)',
    'supervisorCount': 'Jumlah pengawas',
    'from': 'Tanggal awal YYYY-MM-DD (opsional)',
    'to': 'Tanggal akhir YYYY-MM-DD (opsional)',
    'note': 'Catatan',
  };
  @override
  void initState() {
    super.initState();
    original = widget.book['finance'];
    final inputs = {
      ...{
        'profit': 0,
        'chairPercent': 15,
        'treasurerPercent': 10,
        'supervisorPercent': 5,
        'supervisorCount': 1,
        'from': '',
        'to': '',
        'note': '',
      },
      ...object(object(original)['inputs']),
    };
    manual = object(object(original)['inputs'])['basis'] == 'manual';
    for (final e in titles.entries) {
      fields[e.key] = TextEditingController(text: '${inputs[e.key]}');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Json data() {
    final d = <String, dynamic>{'basis': manual ? 'manual' : 'actual'};
    for (final key in titles.keys) {
      final text = fields[key]!.text;
      if (['from', 'to', 'note'].contains(key)) {
        d[key] = text;
      } else if (key == 'profit') {
        d[key] = int.tryParse(text.replaceAll('.', '')) ?? -1;
      } else {
        d[key] = double.tryParse(text.replaceAll(',', '.')) ?? -1;
      }
    }
    return d;
  }

  Json calculate(Json d) {
    for (final key in ['from', 'to']) {
      require(
        s(d, key).isEmpty || validDate(s(d, key)),
        'Tanggal tidak valid.',
      );
    }
    require(
      s(d, 'from').isEmpty ||
          s(d, 'to').isEmpty ||
          s(d, 'from').compareTo(s(d, 'to')) <= 0,
      'Rentang tanggal terbalik.',
    );
    require(n(d, 'profit') >= 0, 'Laba manual tidak valid.');
    for (final key in [
      'chairPercent',
      'treasurerPercent',
      'supervisorPercent',
    ]) {
      final v = n(d, key);
      require(
        v >= 0 && v <= 100 && (v * 100 - (v * 100).round()).abs() < 0.000001,
        'Persentase maksimal 2 desimal.',
      );
    }
    final count = n(d, 'supervisorCount');
    require(
      count >= 1 && count <= 100 && count == count.round(),
      'Jumlah pengawas 1–100.',
    );
    final report = Report(
      rows(widget.book['records']),
      from: s(d, 'from'),
      to: s(d, 'to'),
    );
    require(manual || report.missing < 0.000001, 'Riwayat stok tidak lengkap.');
    return splitProfit(
      manual ? n(d, 'profit').toInt() : report.profit,
      chair: (n(d, 'chairPercent') * 100).round(),
      treasurer: (n(d, 'treasurerPercent') * 100).round(),
      supervisors: (n(d, 'supervisorPercent') * 100).round(),
      count: count.toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Json? shares;
    try {
      shares = calculate(data());
    } catch (_) {}
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Gunakan laba manual'),
          value: manual,
          onChanged: (v) => setState(() => manual = v),
        ),
        for (final e in titles.entries)
          if (e.key != 'profit' || manual)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: fields[e.key],
                inputFormatters: e.key == 'profit' ? [MoneyFormatter()] : null,
                decoration: InputDecoration(labelText: e.value),
                onChanged: (_) => setState(() {}),
              ),
            ),
        if (shares != null)
          for (final e in {
            'chair': 'Ketua',
            'treasurer': 'Bendahara',
            'supervisors': 'Seluruh pengawas',
            'capital': 'Tambahan modal',
            'perSupervisor': 'Per pengawas',
            'remainder': 'Sisa pembulatan pengawas',
          }.entries)
            ListTile(
              title: Text(e.value),
              trailing: Text(money(n(shares, e.key))),
            ),
        const Text(
          'Rencana ini tidak membuat transaksi honor. Laba mencakup piutang; periksa kas sebelum membagikan.',
        ),
        if (message != null) Text(message!),
        FilledButton(
          onPressed: () async {
            try {
              final d = data();
              calculate(d);
              final saved = {
                'inputs': d,
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              };
              await widget.store.save('finance', '', saved, original);
              original = saved;
              if (mounted) setState(() => message = 'Rencana tersimpan lokal.');
            } catch (e) {
              if (mounted) setState(() => message = '$e');
            }
          },
          child: const Text('Simpan rencana'),
        ),
      ],
    );
  }
}

class SimulationPanel extends StatefulWidget {
  final Json book;
  final BookStore store;
  const SimulationPanel({super.key, required this.book, required this.store});
  @override
  State<SimulationPanel> createState() => _SimulationPanelState();
}

class _SimulationPanelState extends State<SimulationPanel> {
  final fields = <String, TextEditingController>{};
  dynamic original;
  String? message;
  @override
  void initState() {
    super.initState();
    original = widget.book['simulation'];
    final inputs = object(object(original)['inputs']);
    for (final prefix in ['urea', 'phoska']) {
      for (final kind in ['Subsidy', 'NonSubsidy']) {
        for (final unit in ['Sacks', 'Price']) {
          final key = '$prefix$kind$unit';
          fields[key] = TextEditingController(
            text: inputs[key] == null ? '' : '${inputs[key]}',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Json data() => {
    for (final e in fields.entries)
      e.key: e.value.text.isEmpty
          ? null
          : e.key.endsWith('Price')
          ? int.tryParse(e.value.text.replaceAll('.', ''))
          : double.tryParse(e.value.text.replaceAll(',', '.')),
  };
  @override
  Widget build(BuildContext context) {
    final all = rows(widget.book['records']),
        report = Report(all),
        inputs = data(),
        purchases = all.where((r) => r['type'] == 'purchase').toList();
    final totalSacks = purchases
        .where((r) => ['urea', 'phoska'].contains(productKey(r)))
        .fold<double>(0, (sum, r) => sum + n(r, 'qty') / 50);
    final general = all
        .where(
          (r) =>
              r['type'] == 'expense' &&
              !['urea', 'phoska'].contains(productKey(r)),
        )
        .fold<int>(0, (sum, r) => sum + n(r, 'amount').toInt());
    double revenue = 0, cost = 0;
    bool known = true, shortage = false;
    final widgets = <Widget>[];
    for (final prefix in ['urea', 'phoska']) {
      final bought = purchases.where((r) => productKey(r) == prefix),
          sacks = bought.fold<double>(0, (sum, r) => sum + n(r, 'qty') / 50),
          buyCost = bought.fold<int>(
            0,
            (sum, r) => sum + n(r, 'amount').toInt(),
          ),
          expenses = all
              .where((r) => r['type'] == 'expense' && productKey(r) == prefix)
              .fold<int>(0, (sum, r) => sum + n(r, 'amount').toInt());
      final landed = sacks > 0
          ? (buyCost +
                    expenses +
                    (totalSacks > 0 ? general * sacks / totalSacks : 0)) /
                sacks
          : null;
      double planned = 0;
      widgets.add(
        Text(
          '${prefix == 'urea' ? 'Urea' : 'Phoska'} • stok ${(report.stock[prefix] ?? 0) / 50} sak',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      );
      widgets.add(
        Text(
          'Biaya per sak: ${landed == null ? 'Belum ada pembelian' : money(landed)}',
        ),
      );
      for (final kind in ['Subsidy', 'NonSubsidy']) {
        widgets.add(Text(kind == 'Subsidy' ? 'Subsidi' : 'Non subsidi'));
        for (final unit in ['Sacks', 'Price']) {
          final key = '$prefix$kind$unit';
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                controller: fields[key],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: unit == 'Price' ? [MoneyFormatter()] : null,
                decoration: InputDecoration(
                  labelText: unit == 'Sacks' ? 'Jumlah sak' : 'Harga per sak',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          );
        }
        final q = inputs['$prefix${kind}Sacks'] as num?,
            price = inputs['$prefix${kind}Price'] as num?;
        if (q == null) {
          known = false;
        } else {
          planned += q;
          if (q != 0) {
            if (price == null || landed == null) {
              known = false;
            } else {
              revenue += q * price;
              cost += q * landed;
            }
          }
        }
      }
      shortage =
          shortage || planned > (report.stock[prefix] ?? 0) / 50 + 0.000001;
      widgets.add(
        Text(
          'Rencana $planned sak • sisa ${(report.stock[prefix] ?? 0) / 50 - planned} sak',
        ),
      );
      widgets.add(const Divider());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...widgets,
        if (shortage)
          const Text(
            'Rencana melebihi stok.',
            style: TextStyle(color: Colors.red),
          ),
        if (known && !shortage) ...[
          ListTile(
            title: const Text('Rencana pendapatan'),
            trailing: Text(money(revenue)),
          ),
          ListTile(
            title: const Text('Rencana laba tambahan'),
            trailing: Text(money(revenue - cost)),
          ),
          ListTile(
            title: const Text('Kas setelah penjualan tunai'),
            trailing: Text(money(report.cash + revenue)),
          ),
          ListTile(
            title: const Text('Kas setelah pelunasan utang'),
            trailing: Text(
              money(report.cash + revenue - report.outstanding('purchase')),
            ),
          ),
        ],
        const Text(
          'Simulasi memakai stok dan biaya pembelian aktual, termasuk alokasi ongkos. Ini rencana, belum menjadi transaksi.',
        ),
        if (message != null) Text(message!),
        FilledButton(
          onPressed: () async {
            try {
              for (final e in inputs.entries) {
                final v = e.value as num?;
                require(
                  fields[e.key]!.text.isEmpty || v != null,
                  'Angka tidak valid.',
                );
                require(
                  v == null ||
                      v.isFinite &&
                          v >= 0 &&
                          v <= (e.key.endsWith('Price') ? 100000000 : 1000000),
                  'Nilai simulasi tidak valid.',
                );
                if (v != null && e.key.endsWith('Sacks')) {
                  require(
                    (v * 100 - (v * 100).round()).abs() < 0.000001,
                    'Jumlah sak maksimal 2 desimal.',
                  );
                }
              }
              final saved = {
                'inputs': inputs,
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              };
              await widget.store.save('simulation', '', saved, original);
              original = saved;
              if (mounted) setState(() => message = 'Rencana tersimpan.');
            } catch (e) {
              if (mounted) setState(() => message = '$e');
            }
          },
          child: const Text('Simpan simulasi'),
        ),
      ],
    );
  }
}
