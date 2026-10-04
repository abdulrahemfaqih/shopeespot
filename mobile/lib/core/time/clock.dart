import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  FixedClock(this._fixedTime);

  DateTime _fixedTime;

  @override
  DateTime now() => _fixedTime;

  void setTime(DateTime time) {
    _fixedTime = time;
  }
}

final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});
