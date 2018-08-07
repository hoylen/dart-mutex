# mutex

A library for mutual exclusion.

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
    assert(y == 42 || y != 42); // y might have changed

An example is when Dart is used to implement a server-side Web server
that updates a database. The update involves querying the database,
performing some calculations, and then updating the database; and
you don't want the database to be changed by something else before you
are finished updating it. That something else could be the same Web
server handling another request in parallel.

This package provides a normal mutex and a read-write mutex.

## Mutex

A mutex guarantees only one lock can be acquired at any one time.

    import 'package:mutex/mutex.dart';

    m = new Mutex();

    await m.acquire();
    try {
      // critical section
    }
    finally {
      m.release();
    }

## Read-write mutex

A read-write mutex allow multiple reads locks to be acquired
at the same time, but all at most one write lock can be acquired
at the same time.

    import 'package:mutex/mutex.dart';

    m = new MutexReadWrite();
 
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
