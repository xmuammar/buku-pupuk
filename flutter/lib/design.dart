import 'package:flutter/material.dart';
import 'domain.dart';
import 'exports.dart';

const ink = Color(0xff172E25),
    muted = Color(0xff738079),
    green = Color(0xff176B45),
    canvas = Color(0xffF4F7F3);
ThemeData bookTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: green, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -.6,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 76,
      titleSpacing: 20,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xffE8EEE8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: muted, fontSize: 14),
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffDFE7DF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffDFE7DF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: green, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: Color(0xffD8E5D9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xffDCF0DE),
      height: 78,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? green : muted,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

IconData transactionIcon(String type) => switch (type) {
  'purchase' => Icons.inventory_2_outlined,
  'sale' => Icons.shopping_bag_outlined,
  'withdraw' => Icons.account_balance_outlined,
  'expense' => Icons.receipt_long_outlined,
  'pay' => Icons.payments_outlined,
  'collect' => Icons.call_received_rounded,
  _ => Icons.swap_horiz_rounded,
};
Color transactionColor(String type) => switch (type) {
  'sale' || 'collect' => green,
  'purchase' => const Color(0xff536CBE),
  'expense' || 'pay' => const Color(0xffB17536),
  _ => const Color(0xff667770),
};

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Color(0xffE4EEE3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: green),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

class SyncStrip extends StatelessWidget {
  final bool connected, sending;
  final int pending;
  final VoidCallback onSync;
  const SyncStrip({
    super.key,
    required this.connected,
    required this.sending,
    required this.pending,
    required this.onSync,
  });
  @override
  Widget build(BuildContext context) {
    final color = connected ? green : const Color(0xff9D702F);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: connected ? const Color(0xffE8F1E7) : const Color(0xffFFF1DA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                pending > 0
                    ? '$pending perubahan menunggu sinkronisasi'
                    : connected
                    ? 'Data tersinkron'
                    : 'Offline · data tersimpan di HP',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (sending)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Sinkronkan',
                  onPressed: onSync,
                  icon: Icon(Icons.sync_rounded, size: 19, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TransactionCard extends StatelessWidget {
  final Json record;
  final VoidCallback onTap;
  const TransactionCard({super.key, required this.record, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final type = s(record, 'type'), color = transactionColor(type);
    final product = s(record, 'product'), note = s(record, 'note');
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(transactionIcon(type), color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s(record, 'name'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          labels[type] ?? '',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: muted,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(
                    s(record, 'date'),
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  if (product.isNotEmpty)
                    Text(
                      '$product · ${n(record, 'qty')} kg',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                money(n(record, 'amount')),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -.5,
                ),
              ),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = green,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 5),
          SizedBox(
            height: 27,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Dashboard extends StatelessWidget {
  final Report report;
  final List<Json> records;
  final void Function(String) onEdit, onNavigate;
  const Dashboard({
    super.key,
    required this.report,
    required this.records,
    required this.onEdit,
    required this.onNavigate,
  });
  @override
  Widget build(BuildContext context) {
    final recent = [...records]
      ..sort((a, b) => s(b, 'date').compareTo(s(a, 'date')));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text('Halo, Muammar', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        const Text(
          'Kelola usaha pupuk dengan lebih teratur.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff176B45), Color(0xff104F35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xffBADCC5),
                    size: 19,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Saldo kas',
                    style: TextStyle(color: Color(0xffDBEEE1), fontSize: 13),
                  ),
                  Spacer(),
                  Icon(Icons.eco_outlined, color: Color(0xffBADCC5), size: 24),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(report.cash),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xff40795C), height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${records.length} transaksi tercatat',
                      style: const TextStyle(
                        color: Color(0xffDBEEE1),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Text(
                    'BUMDes Desa Kabat',
                    style: TextStyle(color: Color(0xffDBEEE1), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onEdit('purchase'),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('Beli pupuk'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onEdit('sale'),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('Jual pupuk'),
              ),
            ),
          ],
        ),
        const SectionTitle('Ringkasan usaha'),
        LayoutBuilder(
          builder: (c, size) {
            final width = (size.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'Penjualan',
                    value: money(report.sales),
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'Pembelian',
                    value: money(report.purchases),
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xff536CBE),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'Piutang petani',
                    value: money(report.outstanding('sale')),
                    icon: Icons.people_alt_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'Utang distributor',
                    value: money(report.outstanding('purchase')),
                    icon: Icons.payments_outlined,
                    color: const Color(0xffB17536),
                  ),
                ),
              ],
            );
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded, color: green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Laba usaha',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Setelah HPP FIFO dan biaya',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    report.missing > 0
                        ? 'Stok belum lengkap'
                        : money(report.profit),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Catat transaksi lainnya'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in ['withdraw', 'expense', 'pay', 'collect'])
              ActionChip(
                avatar: Icon(transactionIcon(type), size: 17, color: green),
                label: Text(
                  labels[type]!,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => onEdit(type),
              ),
          ],
        ),
        SectionTitle(
          'Transaksi terbaru',
          action: 'Lihat semua',
          onAction: () => onNavigate('Buku kas'),
        ),
        if (recent.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada transaksi',
            description:
                'Mulai dengan mencatat pembelian atau penjualan pupuk.',
          )
        else
          for (final r in recent.take(3))
            TransactionCard(record: r, onTap: () => onNavigate('Buku kas')),
        const SizedBox(height: 12),
        const Text(
          '© 2026 · Hak cipta aplikasi milik Muammar, SST, M.Kom',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

const menuItems = <String, (IconData, String)>{
  'Stok pupuk': (Icons.inventory_2_outlined, 'Persediaan, utang & piutang'),
  'Simulasi': (Icons.calculate_outlined, 'Rencana penjualan pupuk'),
  'Buku kas': (Icons.account_balance_wallet_outlined, 'Semua transaksi usaha'),
  'Keuangan': (Icons.pie_chart_outline_rounded, 'Rencana pembagian laba'),
  'Laporan': (Icons.bar_chart_rounded, 'Ringkasan & ekspor laporan'),
  'Cadangan': (Icons.cloud_download_outlined, 'Simpan salinan data'),
};

class MoreMenu extends StatelessWidget {
  final void Function(String) onNavigate;
  const MoreMenu({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    children: [
      Text(
        'Semua kebutuhan usaha',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      const Text(
        'Pantau stok, rencanakan laba, dan siapkan laporan.',
        style: TextStyle(color: muted, fontSize: 13),
      ),
      const SizedBox(height: 24),
      for (final e in menuItems.entries)
        Card(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffE9F2E7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(e.value.$1, color: green),
            ),
            title: Text(e.key, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(
              e.value.$2,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: muted),
            onTap: () => onNavigate(e.key),
          ),
        ),
      const SizedBox(height: 20),
    ],
  );
}
