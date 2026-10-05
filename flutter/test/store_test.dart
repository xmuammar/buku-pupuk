import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buku_pupuk/domain.dart';
import 'package:buku_pupuk/store.dart';

class FakeBackend implements BookBackend {
  Json remote = emptyBook();
  bool online = false;
  int commits = 0;
  final data = StreamController<dynamic>.broadcast();
  final status = StreamController<bool>.broadcast();
  @override
  Stream<dynamic> get values => data.stream;
  @override
  Stream<bool> get connections => status.stream;
  @override
  Future<Json> commit(Json change) async {
    if (!online) throw StateError('Offline');
    commits++;
    remote = applyChange(remote, change);
    data.add(remote);
    return remote;
  }

  void emit({required bool connected}) {
    online = connected;
    status.add(online);
    data.add(remote);
  }

  Future<void> close() async {
    await data.close();
    await status.close();
  }
}

Json withdrawal(int amount) => {
  'id': 'w',
  'type': 'withdraw',
  'date': '2026-10-01',
  'name': 'Dana',
  'product': '',
  'qty': 0,
  'sacks': 0,
  'unit_price': 0,
  'amount': amount,
  'paid': 0,
  'ref': '',
  'note': '',
};
Future<void> drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late FakeBackend backend;
  BookStore? store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = FakeBackend();
  });
  tearDown(() async {
    store?.dispose();
    store = null;
    await backend.close();
  });
  test(
    'offline write is durable before save returns and survives restart',
    () async {
      store = BookStore(prefs, backend: backend, uid: 'test');
      await store!.start();
      backend.emit(connected: false);
      await drain();
      await store!.save('records', 'w', withdrawal(100), null);
      expect(jsonDecode(prefs.getString('queue-test')!), hasLength(1));
      expect(Report(rows(store!.view['records'])).cash, 100);
      expect(backend.commits, 0);
      store!.dispose();
      store = BookStore(prefs, backend: backend, uid: 'test');
      await store!.start();
      expect(store!.pending, hasLength(1));
      backend.emit(connected: true);
      await drain();
      expect(store!.pending, isEmpty);
      expect(Report(rows(backend.remote['records'])).cash, 100);
      expect(backend.commits, 1);
    },
  );
  test(
    'connection before initial data still flushes recovered outbox',
    () async {
      await prefs.setString(
        'queue-test',
        jsonEncode([
          {
            'bucket': 'records',
            'key': 'w',
            'value': withdrawal(100),
            'original': null,
          },
        ]),
      );
      store = BookStore(prefs, backend: backend, uid: 'test');
      await store!.start();
      backend.online = true;
      backend.status.add(true);
      await drain();
      expect(backend.commits, 0);
      backend.data.add(backend.remote);
      await drain();
      expect(backend.commits, 1);
      expect(store!.pending, isEmpty);
    },
  );
  test('concurrent edit retains queue instead of overwriting remote', () async {
    final original = withdrawal(100);
    backend.remote = {
      ...emptyBook(),
      'records': [original],
      'recordCount': 1,
    };
    store = BookStore(prefs, backend: backend, uid: 'test');
    await store!.start();
    backend.emit(connected: false);
    await drain();
    await store!.save('records', 'w', withdrawal(200), original);
    backend.remote = {
      ...backend.remote,
      'records': [withdrawal(300)],
    };
    backend.emit(connected: true);
    await drain();
    expect(n(rows(backend.remote['records']).first, 'amount'), 300);
    expect(store!.pending, hasLength(1));
    expect(store!.error, contains('berubah'));
  });
  test('retry after acknowledged write and app crash is idempotent', () async {
    backend.remote = {
      ...emptyBook(),
      'records': [withdrawal(100)],
      'recordCount': 1,
    };
    await prefs.setString(
      'queue-test',
      jsonEncode([
        {
          'bucket': 'records',
          'key': 'w',
          'value': withdrawal(100),
          'original': null,
        },
      ]),
    );
    store = BookStore(prefs, backend: backend, uid: 'test');
    await store!.start();
    backend.emit(connected: true);
    await drain();
    expect(rows(backend.remote['records']), hasLength(1));
    expect(store!.pending, isEmpty);
  });
}
