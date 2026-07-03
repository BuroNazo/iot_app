import '../models/schedule.dart';

class NowInfo {
  final int hour;
  final int minute;
  final int dayOfWeek; // 1=Pzt ... 7=Paz
  final String dateStr; // "yyyy-MM-dd"
  final int nowMs;

  NowInfo({
    required this.hour,
    required this.minute,
    required this.dayOfWeek,
    required this.dateStr,
    required this.nowMs,
  });

  factory NowInfo.fromDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return NowInfo(
      hour: dt.hour,
      minute: dt.minute,
      dayOfWeek: dt.weekday, // Dart: 1=Pazartesi ... 7=Pazar, bizim kurallmizla ayni
      dateStr: '$y-$m-$d',
      nowMs: dt.millisecondsSinceEpoch,
    );
  }
}

class EvaluationResult {
  final bool shouldTrigger;
  final Map<String, dynamic> scheduleUpdates;

  EvaluationResult({required this.shouldTrigger, required this.scheduleUpdates});
}

EvaluationResult evaluateSchedule(Schedule schedule, NowInfo now) {
  if (!schedule.enabled) {
    return EvaluationResult(shouldTrigger: false, scheduleUpdates: const {});
  }

  if (schedule.type == ScheduleType.time) {
    final scheduledMinutes = (schedule.hour ?? 0) * 60 + (schedule.minute ?? 0);
    final nowMinutes = now.hour * 60 + now.minute;
    final timeHasPassed = nowMinutes >= scheduledMinutes;
    final matchesDay = (schedule.days ?? const []).contains(now.dayOfWeek);
    final alreadyTriggeredToday = schedule.lastTriggeredDate == now.dateStr;

    if (timeHasPassed && matchesDay && !alreadyTriggeredToday) {
      return EvaluationResult(
        shouldTrigger: true,
        scheduleUpdates: {'lastTriggeredDate': now.dateStr},
      );
    }
    return EvaluationResult(shouldTrigger: false, scheduleUpdates: const {});
  }

  // countdown
  if ((schedule.triggerAt ?? 0) <= now.nowMs) {
    return EvaluationResult(
      shouldTrigger: true,
      scheduleUpdates: const {'enabled': false},
    );
  }
  return EvaluationResult(shouldTrigger: false, scheduleUpdates: const {});
}

String toggleCommand(String? currentState) {
  return currentState == 'ON' ? 'OFF' : 'ON';
}
