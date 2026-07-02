import 'package:flutter_test/flutter_test.dart';
import 'package:esp01_controller/models/schedule.dart';

void main() {
  group('Schedule.fromMap', () {
    test('parses a time schedule', () {
      final schedule = Schedule.fromMap('s1', {
        'type': 'time',
        'enabled': true,
        'hour': 22,
        'minute': 30,
        'days': [1, 2, 3, 4, 5],
        'lastTriggeredDate': '2026-07-01',
      });

      expect(schedule.id, 's1');
      expect(schedule.type, ScheduleType.time);
      expect(schedule.enabled, true);
      expect(schedule.hour, 22);
      expect(schedule.minute, 30);
      expect(schedule.days, [1, 2, 3, 4, 5]);
      expect(schedule.lastTriggeredDate, '2026-07-01');
    });

    test('parses a countdown schedule', () {
      final schedule = Schedule.fromMap('s2', {
        'type': 'countdown',
        'enabled': true,
        'minutes': 15,
        'triggerAt': 1751450000000,
      });

      expect(schedule.type, ScheduleType.countdown);
      expect(schedule.minutes, 15);
      expect(schedule.triggerAt, 1751450000000);
    });

    test('defaults enabled to true when missing', () {
      final schedule = Schedule.fromMap('s3', {'type': 'time'});
      expect(schedule.enabled, true);
    });
  });

  group('Schedule.toMap', () {
    test('round trips a time schedule', () {
      final original = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: false,
        hour: 7,
        minute: 5,
        days: [6, 7],
        lastTriggeredDate: '2026-07-01',
      );

      final rebuilt = Schedule.fromMap('s1', original.toMap());

      expect(rebuilt.hour, 7);
      expect(rebuilt.minute, 5);
      expect(rebuilt.days, [6, 7]);
      expect(rebuilt.enabled, false);
    });

    test('round trips a countdown schedule', () {
      final original = Schedule(
        id: 's2',
        type: ScheduleType.countdown,
        enabled: true,
        minutes: 20,
        triggerAt: 123456,
      );

      final rebuilt = Schedule.fromMap('s2', original.toMap());

      expect(rebuilt.minutes, 20);
      expect(rebuilt.triggerAt, 123456);
    });
  });

  group('Schedule.summary', () {
    test('formats a time schedule with days', () {
      final schedule = Schedule(
        id: 's1',
        type: ScheduleType.time,
        enabled: true,
        hour: 9,
        minute: 5,
        days: [1, 3, 5],
      );

      expect(schedule.summary, 'Pzt, Çar, Cum 09:05');
    });

    test('formats a countdown schedule', () {
      final schedule = Schedule(
        id: 's2',
        type: ScheduleType.countdown,
        enabled: true,
        minutes: 15,
      );

      expect(schedule.summary, '15 dk sonra');
    });
  });
}
