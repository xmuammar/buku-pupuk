import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';

abstract class BookBackend {
  Stream<dynamic> get values;
  Stream<bool> get connections;
  Future<Json> commit(Json change);
}

class FirebaseBackend implements BookBackend {
  final DatabaseReference ref = FirebaseDatabase.instance.ref('buku-pupuk');
  @override
  Stream<dynamic> get values =>
      ref.onValue.map((event) => event.snapshot.value);
  @override
  Stream<bool> get connections => FirebaseDatabase.instance
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);
  @override
  Future<Json> commit(Json change) async {
    // Prime the SDK cache before transactions, whose first callback may receive null.
    await ref.get();
    String? conflict;
    final result = await ref.runTransaction((data) {
      try {
        return Transaction.success(applyChange(readBook(data), change));
      } catch (e) {
        conflict = '$e';
        return Transaction.abort();
      }
    }, applyLocally: false);
    if (!result.committed) {
      throw StateError(conflict ?? 'Perubahan ditolak Firebase.');
    }
    return readBook(result.snapshot.value);
  }
}

class BookStore extends ChangeNotifier {
  final BookBackend backend;
  final String uid;
  final SharedPreferences prefs;
  Json book = emptyBook();
  final List<Json> pending = [];
  bool connected = false, ready = false, sending = false;
  String? error;
  StreamSubscription<dynamic>? _data;
  StreamSubscription<bool>? _connection;
  bool _disposed = false;
  Future<void> _localWork = Future<void>.value();
  Future<void> _local(Future<void> Function() operation) {
    final result = _localWork.then((_) => operation());
    _localWork = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  BookStore(this.prefs, {BookBackend? backend, String? uid})
    : backend = backend ?? FirebaseBackend(),
      uid = uid ?? FirebaseAuth.instance.currentUser!.uid;
  String get cacheKey => 'book-$uid';
  String get queueKey => 'queue-$uid';
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> start() async {
    final cached = prefs.getString(cacheKey), queue = prefs.getString(queueKey);
    try {
      if (cached != null) {
        book = readBook(jsonDecode(cached));
        ready = true;
      }
      if (queue != null) pending.addAll(rows(jsonDecode(queue)));
    } catch (e) {
      error = 'Cadangan lokal tidak dapat dibaca: $e';
      notifyListeners();
      return;
    }
    _data = backend.values.listen(
      (event) async {
        try {
          book = readBook(event);
          ready = true;
          await prefs.setString(cacheKey, jsonEncode(book));
          if (!sending && pending.isEmpty) error = null;
          notifyListeners();
          if (connected) unawaited(flush());
        } catch (e) {
          error = '$e';
          notifyListeners();
        }
      },
      onError: (Object e) {
        error = 'Database belum dapat dibaca: $e';
        notifyListeners();
      },
    );
    _connection = backend.connections.listen(
      (online) {
        connected = online;
        notifyListeners();
        if (connected) unawaited(flush());
      },
      onError: (Object e) {
        connected = false;
        error = 'Koneksi belum tersedia: $e';
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Json get view {
    var b = book;
    for (final c in pending) {
      try {
        b = applyChange(b, c);
      } catch (_) {
        break;
      }
    }
    return b;
  }

  Future<void> save(
    String bucket,
    String key,
    dynamic value,
    dynamic original,
  ) async {
    require(ready, 'Tunggu database selesai dimuat.');
    final change = <String, dynamic>{
      'bucket': bucket,
      'key': key,
      'value': value,
      'original': original,
    };
    await _local(() async {
      applyChange(view, change);
      final next = [...pending, change];
      require(
        await prefs.setString(queueKey, jsonEncode(next)),
        'Penyimpanan lokal gagal.',
      );
      pending.add(change);
    });
    notifyListeners();
    unawaited(flush());
  }

  Future<void> flush() async {
    if (sending || !connected || !ready || pending.isEmpty) return;
    sending = true;
    notifyListeners();
    try {
      while (connected && pending.isNotEmpty) {
        await _localWork;
        if (_disposed || !connected || pending.isEmpty) break;
        final change = pending.first;
        book = await backend.commit(change);
        await prefs.setString(cacheKey, jsonEncode(book));
        await _local(() async {
          final next = pending.skip(1).toList();
          require(
            await prefs.setString(queueKey, jsonEncode(next)),
            'Antrean lokal belum dapat diperbarui.',
          );
          pending.removeAt(0);
        });
        error = null;
        notifyListeners();
      }
    } catch (e) {
      error = 'Belum tersinkron: $e';
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> discardConflict() async {
    require(!sending, 'Tunggu sinkronisasi selesai.');
    await _local(() async {
      require(!sending, 'Tunggu sinkronisasi selesai.');
      require(
        await prefs.setString(queueKey, '[]'),
        'Antrean lokal belum dapat diperbarui.',
      );
      pending.clear();
    });
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _data?.cancel();
    _connection?.cancel();
    super.dispose();
  }
}
