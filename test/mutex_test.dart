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

/// Account simulating the classic "simultaneous update" concurrency problem.
///
/// The deposit operation reads the balance, waits for a short time (where
/// problems can occur if the balance is changed) and then writes out the
/// new balance.
///
class Account {
  int get balance => _balance;
  int _balance = 0;

  int _operation = 0;

  Mutex mutex = Mutex();

  /// Set to true to print out read/write to the balance during deposits
  static final bool debugOutput = false;

  /// Time used for calculating time offsets in debug messages.
  DateTime _startTime = DateTime.now();

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
    _balance = startingBalance;
    if (debugOutput) {
      _startTime = DateTime.now();
      _debugPrint();
    }
  }

  /// Waits [startDelay] and then invokes critical section without mutex.
  ///
  Future<void> depositUnsafe(
      int amount, int startDelay, int dangerWindow) async {
    await sleep(Duration(milliseconds: startDelay));
    await _depositCriticalSection(amount, dangerWindow);
  }

  /// Waits [startDelay] and then invokes critical section with mutex.
  ///
  Future<void> depositWithMutex(
      int amount, int startDelay, int dangerWindow) async {
    await sleep(Duration(milliseconds: startDelay));

    await mutex.acquire();
    try {
      expect(mutex.isLocked, isTrue);
      await _depositCriticalSection(amount, dangerWindow);
      expect(mutex.isLocked, isTrue);
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
  Future _depositCriticalSection(int amount, int dangerWindow) async {
    final op = ++_operation;

    _debugPrint('[$op] read balance: $_balance');

    final tmp = _balance;
    await sleep(Duration(milliseconds: dangerWindow));
    _balance = tmp + amount;

    _debugPrint('[$op] write balance: $_balance (= $tmp + $amount)');
  }
}

//----------------------------------------------------------------

void main() {
  final correctBalance = 68;

  final account = Account();

  test('without mutex', () async {
    // First demonstrate that without mutex incorrect results are produced.

    // Without mutex produces incorrect result
    // 000. a reads 0
    // 025. b reads 0
    // 050. a writes 42
    // 075. b writes 26
    account.reset();
    await Future.wait<void>([
      account.depositUnsafe(42, 0, 50),
      account.depositUnsafe(26, 25, 50) // result overwrites first deposit
    ]);
    expect(account.balance, equals(26)); // incorrect: first deposit lost

    // Without mutex produces incorrect result
    // 000. b reads 0
    // 025. a reads 0
    // 050. b writes 26
    // 075. a writes 42
    account.reset();
    await Future.wait([
      account.depositUnsafe(42, 25, 50), // result overwrites second deposit
      account.depositUnsafe(26, 0, 50)
    ]);
    expect(account.balance, equals(42)); // incorrect: second deposit lost
  });

  test('with mutex', () async {
// Test correct results are produced with mutex

    // With mutex produces correct result
    // 000. a acquires lock
    // 000. a reads 0
    // 025. b is blocked
    // 050. a writes 42
    // 050. a releases lock
    // 050. b acquires lock
    // 050. b reads 42
    // 100. b writes 68
    account.reset();
    await Future.wait([
      account.depositWithMutex(42, 0, 50),
      account.depositWithMutex(26, 25, 50)
    ]);
    expect(account.balance, equals(correctBalance));

    // With mutex produces correct result
    // 000. b acquires lock
    // 000. b reads 0
    // 025. a is blocked
    // 050. b writes 26
    // 050. b releases lock
    // 050. a acquires lock
    // 050. a reads 26
    // 100. a writes 68
    account.reset();
    await Future.wait([
      account.depositWithMutex(42, 25, 50),
      account.depositWithMutex(26, 0, 50)
    ]);
    expect(account.balance, equals(correctBalance));
  });

  test('multiple acquires are serialized', () async {
    // Demonstrate that sections running in a mutex are effectively serialized
    const delay = 200; // milliseconds
    account.reset();
    await Future.wait([
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
      account.depositWithMutex(1, 0, delay),
    ]);
    expect(account.balance, equals(10));
  });
}
