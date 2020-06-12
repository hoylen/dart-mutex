import 'dart:async';
import 'package:test/test.dart';
import 'package:mutex/mutex.dart';

/// Wait for duration.
///
/// During this time other code may execute, which could lead to race conditions
/// if critical sections of code are not protected.
///
Future sleep([Duration duration]) async {
  assert(duration != null && duration is Duration);

  final completer = Completer<void>();
  Timer(duration, completer.complete);

  return completer.future;
}

class RWTester {
  RWTester() {
    _startTime = DateTime.now();
  }

  int _operation = 0;
  final _operationSequences = <int>[];

  /// Execution sequence of the operations done.
  ///
  /// Each element corresponds to the position of the initial execution
  /// order of the read/write operation future.
  List<int> get operationSequences => _operationSequences;

  ReadWriteMutex mutex = ReadWriteMutex();

  /// Set to true to print out read/write to the balance during deposits
  static final bool debugOutput = false;

  DateTime _startTime;

  void _debugPrint([String message]) {
    if (debugOutput) {
      if (message != null) {
        final t = DateTime.now().difference(_startTime).inMilliseconds;
        print('$t: $message');
      } else {
        print('');
      }
    }
  }

  void reset() {
    _operationSequences.clear();
    if (debugOutput) {
      _startTime = DateTime.now();
      _debugPrint();
    }
  }

  /// Waits [startDelay] and then invokes critical section with mutex.
  ///
  /// Writes to [_operationSequences]. If the readwrite locks are respected
  /// then the final state of the list will be in ascending order.
  Future<void> writing(int startDelay, int sequence, int endDelay) async {
    await sleep(Duration(milliseconds: startDelay));

    await mutex.protectWrite(() async {
      final op = ++_operation;
      _debugPrint('[$op] write start: <- $_operationSequences');
      final tmp = _operationSequences;
      expect(mutex.isWriteLocked, isTrue);
      expect(_operationSequences, orderedEquals(tmp));
      // Add the position of operation to the list of operations.
      _operationSequences.add(sequence); // add position to list
      expect(mutex.isWriteLocked, isTrue);
      await sleep(Duration(milliseconds: endDelay));
      _debugPrint('[$op] write finish: -> $_operationSequences');
    });
  }

  /// Waits [startDelay] and then invokes critical section with mutex.
  ///
  ///
  Future<void> reading(int startDelay, int sequence, int endDelay) async {
    await sleep(Duration(milliseconds: startDelay));

    await mutex.protectRead(() async {
      final op = ++_operation;
      _debugPrint('[$op] read start: <- $_operationSequences');
      expect(mutex.isReadLocked, isTrue);
      _operationSequences.add(sequence); // add position to list
      await sleep(Duration(milliseconds: endDelay));
      _debugPrint('[$op] read finish: <- $_operationSequences');
    });
  }
}

//----------------------------------------------------------------

void main() {
  final account = RWTester();

  setUp(() {
    account.reset();
  });

  test('multiple read locks', () async {
    await Future.wait([
      account.reading(0, 1, 1000),
      account.reading(0, 2, 900),
      account.reading(0, 3, 800),
      account.reading(0, 4, 700),
      account.reading(0, 5, 600),
      account.reading(0, 6, 500),
      account.reading(0, 7, 400),
      account.reading(0, 8, 300),
      account.reading(0, 9, 200),
      account.reading(0, 10, 100),
    ]);
    // The first future acquires the lock first and waits the longest to give it
    // up. This should however not block any of the other read operations
    // as such the reads should finish in ascending orders.
    expect(
      account.operationSequences,
      orderedEquals(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
    );
  });

  test('multiple write locks', () async {
    await Future.wait([
      account.writing(0, 1, 100),
      account.writing(0, 2, 100),
      account.writing(0, 3, 100),
    ]);
    // The first future writes first and holds the lock until 100 ms
    // Even though the second future starts execution, the lock cannot be
    // acquired until it is released by the first future.
    // Therefore the sequence of operations will be in ascending order
    // of the futures.
    expect(
      account.operationSequences,
      orderedEquals(<int>[1, 2, 3]),
    );
  });

  test('acquireWrite() before acquireRead()', () async {
    const lockTimeout = const Duration(milliseconds: 100);

    final mutex = ReadWriteMutex();

    await mutex.acquireWrite();
    expect(mutex.isReadLocked, equals(false));
    expect(mutex.isWriteLocked, equals(true));

    // Since there is a write lock existing, a read lock cannot be acquired.
    final readLock = mutex.acquireRead().timeout(lockTimeout);
    expect(
      () async => (await readLock),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('acquireRead() before acquireWrite()', () async {
    const lockTimeout = const Duration(milliseconds: 100);

    final mutex = ReadWriteMutex();

    await mutex.acquireRead();
    expect(mutex.isReadLocked, equals(true));
    expect(mutex.isWriteLocked, equals(false));

    // Since there is a read lock existing, a write lock cannot be acquired.
    final writeLock = mutex.acquireWrite().timeout(lockTimeout);
    expect(
      () async => await writeLock,
      throwsA(isA<TimeoutException>()),
    );
  });

  test('mixture of read write locks execution order', () async {
    await Future.wait([
      account.writing(10, 1, 100),
      account.writing(20, 2, 100),
      account.reading(0, 3, 100),
      account.reading(20, 4, 100),
      account.reading(30, 5, 100),
    ]);

    // #3 Read is scheduled first, startDelay = 0, holds lock for 100 ms
    // #4 and #5 are reads scheduled after #3
    // Since multiple read locks are allowed
    // even though #1 and and #2 write operations are scheduled earlier
    // they wait for all read locks to released.
    // This effectively serializes the writes after reads.
    expect(
      account.operationSequences,
      orderedEquals(<int>[3, 4, 5, 1, 2]),
    );
  });

  group('protectRead', () {
    test('lock released on success', () async {
      final m = ReadWriteMutex();

      await m.protectRead(() {
        // critical section
        expect(m.isLocked, isTrue);
      });
      expect(m.isLocked, isFalse);
    });

    test('lock released on exception', () async {
      final m = ReadWriteMutex();

      try {
        await m.protectRead(() {
          // critical section
          expect(m.isLocked, isTrue);
          throw const FormatException('testing');
        });
        fail('exception in critical section was not propagated');
      } on FormatException {
        expect(m.isLocked, isFalse);
      }

      expect(m.isLocked, isFalse);
    });
  });

  group('protectWrite', () {
    test('lock released on success', () async {
      final m = ReadWriteMutex();

      await m.protectWrite(() {
        // critical section
        expect(m.isLocked, isTrue);
      });
      expect(m.isLocked, isFalse);
    });

    test('lock released on exception', () async {
      final m = ReadWriteMutex();

      try {
        await m.protectWrite(() {
          // critical section
          expect(m.isLocked, isTrue);
          throw const FormatException('testing');
        });
        fail('exception in critical section was not propagated');
      } on FormatException {
        expect(m.isLocked, isFalse);
      }

      expect(m.isLocked, isFalse);
    });
  });
}
