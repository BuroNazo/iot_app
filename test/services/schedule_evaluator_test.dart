import 'package:flutter_test/flutter_test.dart';
import 'package:esp01_controller/models/schedule.dart';
import 'package:esp01_controller/services/schedule_evaluator.dart';

void main() {
  NowInfo now({
    int hour = 22,
    int minute = 30,
    int dayOfWeek = 3, // Çarşamba
    String dateStr = '2026-07-02',
    int? nowMs,
  }) {
    return NowInfo(
      hour: hour,
      minute: minute,
      dayOfWeek: dayOfWeek,
      dateStr: dateStr,
      nowMs: nowMs ?? 1751450000000,
    );
  }

  group('evaluateSchedule - time type', () {
    final base = Schedule(
      id: 's1',
      type: ScheduleType.time,
      enabled: true,
      hour: 22,
      minute: 30,
      days: const [3, 4, 5],
    );

    test('triggers when hour, minute and day match and not already triggered today', () {
      final result = evaluateSchedule(base, now());
      expect(result.shouldTrigger, true);
      expect(result.scheduleUpdates, {'lastTriggeredDate': '2026-07-02'});
    });

    test('does not trigger when current time is before the scheduled time', () {
      final result = evaluateSchedule(base, now(minute: 29));
      expect(result.shouldTrigger, false);
    });

    test('triggers (catch-up) when current time is after the scheduled time and not already triggered today', () {
      final result = evaluateSchedule(base, now(hour: 23, minute: 45));
      expect(result.shouldTrigger, true);
      expect(result.scheduleUpdates, {'lastTriggeredDate': '2026-07-02'});
    });

    test('does not trigger when day is not in days list', () {
      final result = evaluateSchedule(base, now(dayOfWeek: 1));
      expect(result.shouldTrigger, false);
    });

    test('does not trigger twice on the same day', () {
      final schedule = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: true,
        hour: 22,
        minute: 30,
        days: const [3, 4, 5],
        lastTriggeredDate: '2026-07-02',
      );
      final result = evaluateSchedule(schedule, now());
      expect(result.shouldTrigger, false);
    });

    test('does not trigger when disabled', () {
      final schedule = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: false,
        hour: 22,
        minute: 30,
        days: const [3, 4, 5],
      );
      final result = evaluateSchedule(schedule, now());
      expect(result.shouldTrigger, false);
    });
  });

  group('evaluateSchedule - countdown type', () {
    final base = Schedule(
      id: 's2',
      type: ScheduleType.countdown,
      enabled: true,
      minutes: 15,
      triggerAt: 1751450000000,
    );

    test('triggers and disables itself when triggerAt has passed', () {
      final result = evaluateSchedule(base, now(nowMs: 1751450000001));
      expect(result.shouldTrigger, true);
      expect(result.scheduleUpdates, {'enabled': false});
    });

    test('does not trigger when triggerAt is in the future', () {
      final result = evaluateSchedule(base, now(nowMs: 1751449999999));
      expect(result.shouldTrigger, false);
    });
  });

  group('toggleCommand', () {
    test('returns OFF when current state is ON', () {
      expect(toggleCommand('ON'), 'OFF');
    });

    test('returns ON when current state is OFF or null', () {
      expect(toggleCommand('OFF'), 'ON');
      expect(toggleCommand(null), 'ON');
    });
  });

  group('NowInfo.fromDateTime', () {
    test('maps DateTime fields to NowInfo correctly', () {
      final dt = DateTime(2026, 7, 2, 22, 30); // Persembe degil, gercek gun onemli degil burada
      final info = NowInfo.fromDateTime(dt);
      expect(info.hour, 22);
      expect(info.minute, 30);
      expect(info.dateStr, '2026-07-02');
      expect(info.dayOfWeek, dt.weekday);
      expect(info.nowMs, dt.millisecondsSinceEpoch);
    });
  });
}
