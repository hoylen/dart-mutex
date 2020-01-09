part of mutex;

/// Mutual exclusion.
///
/// Usage:
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
///
class Mutex {
  // Implemented as a ReadWriteMutex that is used only with write locks.
  final ReadWriteMutex _rwMutex = ReadWriteMutex();

  /// Indicates if a lock has currently been acquired.
  bool get isLocked => (_rwMutex.isLocked);

  /// Acquire a lock
  ///
  /// Returns a future that will be completed when the lock has been acquired.
  ///
  Future acquire() => _rwMutex.acquireWrite();

  /// Release a lock.
  ///
  /// Release a lock that has been acquired.
  ///
  void release() => _rwMutex.release();
}
