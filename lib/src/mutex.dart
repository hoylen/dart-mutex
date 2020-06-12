part of mutex;

/// Mutual exclusion.
///
/// The [protect] method is a convenience method for acquiring a lock before
/// running critical code, and then releasing the lock afterwards. Using this
/// convenience method will ensure the lock is always released after use.
///
/// Usage:
///
///     m = new Mutex();
///
///     await m.protect(() {
///       // critical section
///     });
///
/// Alternatively, a lock can be explicitly acquired and managed. In this
/// situation, the program is responsible for releasing the lock after it
/// have been used. Failure to release the lock will prevent other code for
/// ever acquiring the lock.
///
///     m = new Mutex();
///
///     await m.acquire();
///     try {
///       // critical section
///     }
///     finally {
///       m.release();
///     }

class Mutex {
  // Implemented as a ReadWriteMutex that is used only with write locks.
  final ReadWriteMutex _rwMutex = ReadWriteMutex();

  /// Indicates if a lock has been acquired and not released.
  bool get isLocked => (_rwMutex.isLocked);

  /// Acquire a lock
  ///
  /// Returns a future that will be completed when the lock has been acquired.
  ///
  /// Consider using the convenience method [protect], otherwise the caller
  /// is responsible for making sure the lock is released after it is no longer
  /// needed. Failure to release the lock means no other code can acquire the
  /// lock.

  Future acquire() => _rwMutex.acquireWrite();

  /// Release a lock.
  ///
  /// Release a lock that has been acquired.
  ///
  void release() => _rwMutex.release();

  /// Convenience method for protecting a function with a lock.
  ///
  /// A lock is acquired before invoking the [criticalSection] function.
  /// If the critical section returns a Future, it waits for it to be completed
  /// before the lock is released. The lock is always released
  /// (even if the critical section throws an exception).
  ///
  /// Returns a Future that completes after the lock is released.

  Future<void> protect(Function criticalSection) async {
    await acquire();
    try {
      await criticalSection();
    } finally {
      release();
    }
  }
}
