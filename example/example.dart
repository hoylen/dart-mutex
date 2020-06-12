// Mutex example.
//
// This example demonstrates why a mutex is needed.

import 'dart:async';
import 'dart:math';
import 'package:mutex/mutex.dart';

//----------------------------------------------------------------
// Random asynchronous delays to try and simulate race conditions.

const _maxDelay = 500; // milliseconds

final _random = Random();

Future<void> randomDelay() async {
  await Future<void>.delayed(
      Duration(milliseconds: _random.nextInt(_maxDelay)));
}

//----------------------------------------------------------------
/// Account balance.
///
/// The classical example of a race condition is when a bank account is updated
/// by different simultaneous operations.

int balance = 0;

//----------------------------------------------------------------
/// Deposit without using mutex.

Future<void> unsafeUpdate(int id, int depositAmount) async {
  // Random delay before updating starts
  await randomDelay();

  // Add the deposit to the balance. But this operation is not atomic if
  // there are asynchronous operations in it (as simulated by the randomDelay).

  final oldBalance = balance;
  await randomDelay();
  balance = oldBalance + depositAmount;

  print('  [$id] added $depositAmount to $oldBalance -> $balance');
}

//----------------------------------------------------------------
/// Deposit using mutex.

Mutex m = Mutex();

Future<void> safeUpdate(int id, int depositAmount) async {
  // Random delay before updating starts
  await randomDelay();

  // Acquire the mutex before running the critical section of code

  await m.protect(() async {
    // critical section

    // This is the same as the unsafe update. But since it is performed only
    // when the mutex is acquired, it is safe: no other safe update can happen
    // until this mutex is released.

    final oldBalance = balance;
    await randomDelay();
    balance = oldBalance + depositAmount;

    // end of critical section

    print('  [$id] added $depositAmount to $oldBalance -> $balance');
  });
}

//----------------------------------------------------------------
/// Make a series of deposits and see if the final balance is correct.

Future<void> makeDeposits({bool safe = true}) async {
  print(safe ? 'Using mutex:' : 'Not using mutex:');

  const numberDeposits = 10;
  const amount = 10;

  balance = 0;

  // Create a set of operations, each attempting to deposit the same amount
  // into the account.

  final operations = <Future>[];
  for (var x = 0; x < numberDeposits; x++) {
    final f = (safe) ? safeUpdate(x, amount) : unsafeUpdate(x, amount);
    operations.add(f);
  }

  // Wait for all the deposit operations to finish

  await Future.wait<void>(operations);

  // Check if all of the operations succeeded

  final expected = numberDeposits * amount;
  if (balance != expected) {
    print('Error: deposits were lost (final balance $balance != $expected)');
  } else {
    print('Success: no deposits were lost');
  }
}

//----------------------------------------------------------------

void main() async {
  await makeDeposits(safe: false);
  print('');
  await makeDeposits(safe: true);
}
