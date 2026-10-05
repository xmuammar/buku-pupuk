import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buku_pupuk/design.dart';
import 'package:buku_pupuk/domain.dart';
import 'package:buku_pupuk/main.dart';
import 'package:buku_pupuk/store.dart';

class PreviewBackend implements BookBackend {
  @override
  Stream<dynamic> get values => const Stream.empty();
  @override
  Stream<bool> get connections => const Stream.empty();
  @override
  Future<Json> commit(Json change) => throw UnimplementedError();
}

Json previewBook() => {
  ...emptyBook(),
  'recordCount': 3,
  'records': [
    {
      'id': 'w',
      'type': 'withdraw',
      'date': '2026-10-01',
      'name': 'Modal usaha',
      'product': '',
      'qty': 0,
      'amount': 10000000,
      'paid': 0,
      'ref': '',
      'note': '',
    },
    {
      'id': 'p',
      'type': 'purchase',
      'date': '2026-10-02',
      'name': 'Distributor pupuk',
      'product': 'Urea',
      'qty': 500,
      'sacks': 10,
      'unit_price': 200000,
      'amount': 2000000,
      'paid': 2000000,
      'ref': '',
      'note': '',
    },
    {
      'id': 's',
      'type': 'sale',
      'date': '2026-10-03',
      'name': 'Petani Desa Kabat',
      'product': 'Urea',
      'qty': 100,
      'sacks': 2,
      'unit_price': 250000,
      'amount': 500000,
      'paid': 500000,
      'ref': '',
      'note': 'Penjualan tunai',
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/DejaVuSans.ttf'))
      ..addFont(rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('dashboard and menu fit a $width pixel screen', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = BookStore(prefs, backend: PreviewBackend(), uid: 'preview')
        ..book = previewBook()
        ..ready = true
        ..connected = true;
      addTearDown(store.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: bookTheme(),
          home: RepaintBoundary(
            key: boundary,
            child: Home(initialStore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Saldo kas'), findsOneWidget);
      expect(find.text('Beli pupuk'), findsOneWidget);
      if (width == 390) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/buku-modern-home.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Lainnya'));
      await tester.pumpAndSettle();
      expect(find.text('Semua kebutuhan usaha'), findsOneWidget);
      expect(find.text('Stok pupuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/buku-modern-menu.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Stok pupuk'));
      await tester.pumpAndSettle();
      expect(find.text('Persediaan pupuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('login fits mobile with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: bookTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.4),
          ),
          child: const Login(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
