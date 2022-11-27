## 3.0.1

- Fixed bug with new read mutexes preventing a write mutex from being acquired.

## 3.0.0

- BREAKING CHANGE: critical section functions must return a Future.
    - This is unlikely to affect real-world code, since only functions
      containing asynchronous code would be critical.
- Protect method returns Future to the value from the critical section.

## 2.0.0

- Null safety release.

## 2.0.0-nullsafety.0

- Pre-release version: updated library to null safety (Non-nullable by default).
- Removed support for Dart 1.x.

## 1.1.0

- Added protect, protectRead and protectWrite convenience methods.
- Improved tests to not depend on timing.

## 1.0.3

- Added an example.

## 1.0.2

- Code clean up to satisfy pana 0.13.2 health checks.

## 1.0.1

- Fixed dartanalyzer warnings.

## 1.0.0

- Updated the upper bound of the SDK constraint to <3.0.0.

## 0.0.1

- Initial version
