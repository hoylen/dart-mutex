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
    synchronousOperations();
    assert(x == 42); // x will not have changed
    
    y = 42;
    await asynchronousOperations();
    assert(y == 42 || y != 42); // Warning: y might have been changed

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

Acquiring the lock:

    await m.acquire();
    try {
      // critical section
    }
    finally {
      m.release();
    }

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
    try {
      // critical write section
      // No other locks (read or write) can be acquired.
    }
    finally {
      m.release();
    }

Acquiring a read lock:

    await m.acquireRead();
    try {
      // critical read section
      // No write locks can be acquired, but other read locks can be acquired.
    }
    finally {
      m.release();
    }


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/hoylen/dart-mutex/issues
