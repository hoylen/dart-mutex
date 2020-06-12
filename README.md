# mutex

A library for creating locks to ensure mutual exclusion when
running critical sections of code.

## Purpose

Mutexes can be used to protect critical sections of code to prevent
race conditions.

Although Dart uses a single thread of execution, race conditions
can still occur when asynchronous operations are used inside
critical sections. For example,

    x = 42;
    synchronousOperations(); // this does not modify x
    assert(x == 42); // x will NOT have changed
    
    y = 42; // a variable that other asynchronous code can modify
    await asynchronousOperations(); // this does NOT modify y, but...
    // There is NO GUARANTEE other async code didn't run and change it!
    assert(y == 42 || y != 42); // WARNING: y might have changed

An example is when Dart is used to implement a server-side Web server
that updates a database (assuming database transactions are not being
used). The update involves querying the database, performing
calculations on those retrieved values, and then updating the database
with the result.  You don't want the database to be changed by
"something else" while performing the calculations, since the results
you would write will not incorporate those other changes. That
"something else" could be the same Web server handling another request
in parallel.

This package provides a normal mutex and a read-write mutex.

## Mutex

A mutex guarantees at most only one lock can exist at any one time.

If the lock has already been acquired, attempts to acquire another
lock will be blocked until the lock has been released.

    import 'package:mutex/mutex.dart';

    m = Mutex();

Acquiring the lock before running the critical section of code,
and then releasing the lock.

    await m.acquire();
    // No other lock can be acquired until the lock is released

    try {
      // critical section with asynchronous code
	  await ...
    }
    finally {
      m.release();
    }

The following code uses the _protect_ convenience method to do the
same thing as the above code. Use the convenence method whenever
possible, since it ensures the lock will always be released.

    await m.protect(() async {
	  // critical section
	});

## Read-write mutex

A read-write mutex allows multiple _reads locks_ to be exist
simultaneously, but at most only one _write lock_ can exist at any one
time. A _write lock_ and any _read locks_ cannot both exist together
at the same time.

If there is one or more _read locks_, attempts to acquire a _write
lock_ will be blocked until all the _read locks_ have been
released. But attempts to acquire more _read locks_ will not be
blocked. If there is a _write lock_, attempts to acquire any lock
(read or write) will be blocked until that _write lock_ is released.

A read-write mutex can also be describeed as a single-writer mutex,
multiple-reader mutex, or a reentrant lock.

    import 'package:mutex/mutex.dart';

    m = MutexReadWrite();
 
 Acquiring a write lock:
 
    await m.acquireWrite();
    // No other locks (read or write) can be acquired until released
	
    try {
      // critical write section with asynchronous code
	  await ...
    }
    finally {
      m.release();
    }

Acquiring a read lock:

    await m.acquireRead();
    // No write lock can be acquired until all read locks are released,
	// but additional read locks can be acquired.
	
    try {
      // critical read section with asynchronous code
	  await ...
    }
    finally {
      m.release();
    }

The following code uses the _protectWrite_ and _protectRead_
convenience methods to do the same thing as the above code. Use the
convenence method whenever possible, since it ensures the lock will
always be released.

    await m.protectWrite(() async {
	  // critical write section
	});

    await m.protectRead(() async {
	  // critical read section
	});


## When mutual exclusion is not needed

The critical section should always contain some asynchronous code.  If
the critical section only contains synchronous code, there is no need
to put it in a critical section. In Dart, synchronous code cannot be
interrupted, so there is no need to protect it using mutual exclusion.

Also, if the critical section does not involve data or shared
resources that can be accessed by other asynchronous code, it also
does not need to be protected.  For example, if it only uses local
variables that other asynchronous code won't have access to: while the
other asynchronous code could run, it won't be able to make unexpected
changes to the local variables it can't access.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/hoylen/dart-mutex/issues
