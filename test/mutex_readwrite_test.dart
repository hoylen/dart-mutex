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

  var completer = new Completer();
  new Timer(duration, () {
    completer.complete();
  });

  return completer.future;
}

class RWTester {
  int get numWrites => _numWrites;
  int _numWrites = 0;

  int _operation = 0;

  ReadWriteMutex mutex = new ReadWriteMutex();

  /// Set to true to print out read/write to the balance during deposits
  static final bool debugOutput = false;

  DateTime _startTime;

  void _debugPrint([String message]) {
    if (debugOutput) {
      if (message != null) {
        var t = new DateTime.now().difference(_startTime).inMilliseconds;
        print("$t: $message");
      } else {
        print("");
      }
    }
  }

  /// Constructor for an account.
  ///
  /// Uses RentrantMutex if [reentrant] is true; otherwise uses NormalMutex.
  ///
  RWTester() {
    _startTime = new DateTime.now();
  }

  void reset([int startingBalance = 0]) {
    _numWrites = startingBalance;
    if (debugOutput) {
      _startTime = new DateTime.now();
      _debugPrint();
    }
  }

  /// Waits [startDelay] and then invokes critical section with mutex.
  ///
  Future writing(int startDelay, int dangerWindow) async {
    await sleep(new Duration(milliseconds: startDelay));

    await mutex.acquireWrite();
    try {
      await _writingCriticalSection(dangerWindow);
    } finally {
      mutex.release();
    }
  }

  /// Critical section of adding [amount] to the balance.
  ///
  /// Reads the balance, then sleeps for [dangerWindow] milliseconds, before
  /// saving the new balance. If not protected, another invocation of this
  /// method while it is sleeping will read the balance before it is updated.
  /// The one that saves its balance last will overwrite the earlier saved
  /// balances (effectively those other deposits will be lost).
  ///
  Future _writingCriticalSection(int dangerWindow) async {
    var op = ++_operation;

    _debugPrint("[$op] write start: <- $_numWrites");

    var tmp = _numWrites;
    expect(mutex.isWriteLocked, isTrue);
    await sleep(new Duration(milliseconds: dangerWindow));
    expect(mutex.isWriteLocked, isTrue);
    expect(_numWrites, equals(tmp));

    _numWrites = tmp + 1; // change the balance

    _debugPrint("[$op] write finish: -> $_numWrites");
  }


  /// Waits [startDelay] and then invokes critical section with mutex.
  ///
  /// This method demonstrates the use of a read lock on the mutex.
  ///
  Future<double> reading(int startDelay, int dangerWindow) async {
    await sleep(new Duration(milliseconds: startDelay));

    await mutex.acquireRead();
    try {
      return await _readingCriticalSection(dangerWindow);
    } finally {
      mutex.release();
    }
  }

  /// Critical section that must be done in a read lock.
  ///
  Future _readingCriticalSection(int dangerWindow) async {
    var op = ++_operation;

    _debugPrint("[$op] read start: <- $_numWrites");

    var tmp = _numWrites;
    expect(mutex.isReadLocked, isTrue);
    await sleep(new Duration(milliseconds: dangerWindow));
    expect(mutex.isReadLocked, isTrue);
    expect(_numWrites, equals(tmp));


    _debugPrint("[$op] read finish: <- $_numWrites");
  }
}

//----------------------------------------------------------------

void main() {
  var account = new RWTester();

  test("multiple read locks", () async {
    const int delay = 200; // milliseconds
    const int overhead = 50; // milliseconds
    account.reset();
    var startTime = new DateTime.now();
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
    var finishTime = new DateTime.now();
    var ms = finishTime.difference(startTime).inMilliseconds;
    expect(ms, greaterThan(delay));
    expect(ms, lessThan(delay + overhead));
    expect(account.numWrites, equals(0));
  });

  test("multiple write locks", () async {
    const int delay = 200; // milliseconds
    const int overhead = 100; // milliseconds
    account.reset();
    var startTime = new DateTime.now();
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
    var finishTime = new DateTime.now();
    var ms = finishTime.difference(startTime).inMilliseconds;
    expect(ms, greaterThan(delay * 10));
    expect(ms, lessThan(delay * 10 + overhead));
    expect(account.numWrites, equals(10));
  });

  test("mixture of read and write locks", () async {
    const int delay = 200; // milliseconds
    const int overhead = 100; // milliseconds
    account.reset();
    var startTime = new DateTime.now();
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
    var finishTime = new DateTime.now();
    var ms = finishTime.difference(startTime).inMilliseconds;
    expect(ms, greaterThan(1000 + delay * 9));
    expect(ms, lessThan(1000 + delay * 9 + overhead));
    expect(account.numWrites, equals(7));
  });
}
