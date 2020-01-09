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

  int get numWrites => _numWrites;
  int _numWrites = 0;

  int _operation = 0;

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

  void reset([int startingBalance = 0]) {
    _numWrites = startingBalance;
    if (debugOutput) {
      _startTime = DateTime.now();
      _debugPrint();
    }
  }

  /// Waits [startDelay] and then invokes critical section with mutex.
  ///
  Future<void> writing(int startDelay, int dangerWindow) async {
    await sleep(Duration(milliseconds: startDelay));

    await mutex.acquireWrite();
    try {
      await _writingCriticalSection(dangerWindow);
    } finally {
      mutex.release();
    }
  }

  /// Critical section of adding an amount to the balance.
  ///
  /// Reads the balance, then sleeps for [dangerWindow] milliseconds, before
  /// saving the new balance. If not protected, another invocation of this
  /// method while it is sleeping will read the balance before it is updated.
  /// The one that saves its balance last will overwrite the earlier saved
  /// balances (effectively those other deposits will be lost).
  ///
  Future _writingCriticalSection(int dangerWindow) async {
    final op = ++_operation;

    _debugPrint('[$op] write start: <- $_numWrites');

    final tmp = _numWrites;
    expect(mutex.isWriteLocked, isTrue);
    await sleep(Duration(milliseconds: dangerWindow));
    expect(mutex.isWriteLocked, isTrue);
    expect(_numWrites, equals(tmp));

    _numWrites = tmp + 1; // change the balance

    _debugPrint('[$op] write finish: -> $_numWrites');
  }

  /// Waits [startDelay] and then invokes critical section with mutex.
  ///
  /// This method demonstrates the use of a read lock on the mutex.
  ///
  Future<void> reading(int startDelay, int dangerWindow) async {
    await sleep(Duration(milliseconds: startDelay));

    await mutex.acquireRead();
    try {
      return await _readingCriticalSection(dangerWindow);
    } finally {
      mutex.release();
    }
  }

  /// Critical section that must be done in a read lock.
  ///
  Future<void> _readingCriticalSection(int dangerWindow) async {
    final op = ++_operation;

    _debugPrint('[$op] read start: <- $_numWrites');

    final tmp = _numWrites;
    expect(mutex.isReadLocked, isTrue);
    await sleep(Duration(milliseconds: dangerWindow));
    expect(mutex.isReadLocked, isTrue);
    expect(_numWrites, equals(tmp));

    _debugPrint('[$op] read finish: <- $_numWrites');
  }
}

//----------------------------------------------------------------

void main() {
  final account = RWTester();

  test('multiple read locks', () async {
    const delay = 200; // milliseconds
    const overhead = 50; // milliseconds
    account.reset();
    final startTime = DateTime.now();
    await Future.wait([
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
      account.reading(0, delay),
    ]);
    final finishTime = DateTime.now();
    final ms = finishTime.difference(startTime).inMilliseconds;
    expect(ms, greaterThan(delay));
    expect(ms, lessThan(delay + overhead));
    expect(account.numWrites, equals(0));
  });

  test('multiple write locks', () async {
    const delay = 200; // milliseconds
    const overhead = 100; // milliseconds
    account.reset();
    final startTime = DateTime.now();
    await Future.wait([
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
      account.writing(0, delay),
    ]);
    final finishTime = DateTime.now();
    final ms = finishTime.difference(startTime).inMilliseconds;
    expect(ms, greaterThan(delay * 10));
    expect(ms, lessThan(delay * 10 + overhead));
    expect(account.numWrites, equals(10));
  });

  test('mixture of read and write locks', () async {
    const delay = 200; // milliseconds
    const overhead = 100; // milliseconds
    account.reset();
    final startTime = DateTime.now();
    await Future.wait([
      account.writing(0, 1000),
      account.reading(100, delay),
      account.reading(110, delay),
      account.reading(120, delay),
      account.writing(130, delay),
      account.writing(140, delay),
      account.writing(150, delay),
      account.reading(160, delay),
      account.reading(170, delay),
      account.reading(180, delay),
      account.writing(190, delay),
      account.writing(200, delay),
      account.writing(210, delay),
      account.reading(220, delay),
      account.reading(230, delay),
      account.reading(240, delay),
    ]);
    final finishTime = DateTime.now();
    final ms = finishTime.difference(startTime).inMilliseconds;
    expect(ms, greaterThan(1000 + delay * 9));
    expect(ms, lessThan(1000 + delay * 9 + overhead));
    expect(account.numWrites, equals(7));
  });
}
