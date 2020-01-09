part of mutex;

/// Represents a request for a lock.
///
/// This is instantiated for each acquire and, if necessary, it is added
/// to the waiting queue.
///
class _ReadWriteMutexRequest {
  /// Internal constructor.
  ///
  /// The [isRead] indicates if this is a read lock (true) or a write lock (false).

  _ReadWriteMutexRequest({this.isRead});

  /// Indicates if this is a read or write lock.

  final bool isRead; // true = read lock requested; false = write lock requested

  /// The job's completer.
  ///
  /// This [Completer] will complete when the job has acquired a lock.
  ///
  /// This should be defined as Completer<void>, but void is not supported in
  /// Dart 1 (it only appeared in Dart 2). A type must be defined, otherwise
  /// the Dart 2 dartanalyzer complains.

  final Completer<int> completer = Completer<int>();
}

/// Mutual exclusion that supports read and write locks.
///
/// Multiple read locks can be simultaneously acquired, but at most only
/// one write lock can be acquired at any one time.
///
/// Create the mutex:
///
///     m = new ReadWriteMutex();
///
/// Some code can acquire a write lock:
///
///     await m.acquireWrite();
///     try {
///       // critical write section
///       assert(m.isWriteLocked);
///     }
///     finally {
///       m.release();
///     }
///
/// Other code can acquire a read lock.
///
///     await m.acquireRead();
///     try {
///       // critical read section
///       assert(m.isReadLocked);
///     }
///     finally {
///       m.release();
///     }
///
/// The current implementation lets locks be acquired in first-in-first-out
/// order. This ensures there will not be any lock starvation, which can
/// happen if some locks are prioritised over others. Submit a feature
/// request issue, if there is a need for another scheduling algorithm.
///
class ReadWriteMutex {
  final _waiting = <_ReadWriteMutexRequest>[];

  int _state = 0; // -1 = write lock, +ve = number of read locks; 0 = no lock

  /// Indicates if a lock (read or write) has currently been acquired.
  bool get isLocked => (_state != 0);

  /// Indicates if a write lock has currently been acquired.
  bool get isWriteLocked => (_state == -1);

  /// Indicates if a read lock has currently been acquired.
  bool get isReadLocked => (0 < _state);

  /// Acquire a read lock
  ///
  /// Returns a future that will be completed when the lock has been acquired.
  ///
  Future acquireRead() => _acquire(true);

  /// Acquire a write lock
  ///
  /// Returns a future that will be completed when the lock has been acquired.
  ///
  Future acquireWrite() => _acquire(false);

  /// Release a lock.
  ///
  /// Release a lock that has been acquired.
  ///
  void release() {
    if (_state == -1) {
      // Write lock released
      _state = 0;
    } else if (0 < _state) {
      // Read lock released
      _state--;
    } else if (_state == 0) {
      throw StateError('no lock to release');
    } else {
      assert(false);
    }

    // Let all jobs that can now acquire a lock do so.

    while (_waiting.isNotEmpty) {
      final nextJob = _waiting.first;
      if (_jobAcquired(nextJob)) {
        _waiting.removeAt(0);
      } else {
        break; // no more can be acquired
      }
    }
  }

  /// Internal acquire method.
  ///
  Future _acquire(bool isRead) {
    final newJob = _ReadWriteMutexRequest(isRead: isRead);
    if (!_jobAcquired(newJob)) {
      _waiting.add(newJob);
    }
    return newJob.completer.future;
  }

  /// Determine if the [job] can now acquire the lock.
  ///
  /// If it can acquire the lock, the job's completer is completed, the
  /// state updated, and true is returned. If not, false is returned.
  ///
  bool _jobAcquired(_ReadWriteMutexRequest job) {
    assert(-1 <= _state);
    if (_state == 0 || (0 < _state && job.isRead)) {
      // Can acquire
      _state = (job.isRead) ? (_state + 1) : -1;
      job.completer.complete(0); // dummy value
      return true;
    } else {
      return false;
    }
  }
}
