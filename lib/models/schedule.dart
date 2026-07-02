enum ScheduleType { time, countdown }

class Schedule {
  final String id;
  final ScheduleType type;
  final bool enabled;

  // type == ScheduleType.time için
  final int? hour;
  final int? minute;
  final List<int>? days; // 1=Pzt ... 7=Paz
  final String? lastTriggeredDate; // "yyyy-MM-dd"

  // type == ScheduleType.countdown için
  final int? minutes;
  final int? triggerAt; // epoch ms

  Schedule({
    required this.id,
    required this.type,
    required this.enabled,
    this.hour,
    this.minute,
    this.days,
    this.lastTriggeredDate,
    this.minutes,
    this.triggerAt,
  });

  factory Schedule.fromMap(String id, Map<dynamic, dynamic> map) {
    final type =
        map['type'] == 'countdown' ? ScheduleType.countdown : ScheduleType.time;
    return Schedule(
      id: id,
      type: type,
      enabled: map['enabled'] ?? true,
      hour: map['hour'] as int?,
      minute: map['minute'] as int?,
      days: (map['days'] as List?)?.map((e) => e as int).toList(),
      lastTriggeredDate: map['lastTriggeredDate'] as String?,
      minutes: map['minutes'] as int?,
      triggerAt: map['triggerAt'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    if (type == ScheduleType.time) {
      return {
        'type': 'time',
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'days': days,
        'lastTriggeredDate': lastTriggeredDate,
      };
    }
    return {
      'type': 'countdown',
      'enabled': enabled,
      'minutes': minutes,
      'triggerAt': triggerAt,
    };
  }

  static const Map<int, String> _dayLabels = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çar',
    4: 'Per',
    5: 'Cum',
    6: 'Cmt',
    7: 'Paz',
  };

  String get summary {
    if (type == ScheduleType.time) {
      final dayText = (days ?? []).map((d) => _dayLabels[d] ?? '?').join(', ');
      final h = (hour ?? 0).toString().padLeft(2, '0');
      final m = (minute ?? 0).toString().padLeft(2, '0');
      return '$dayText $h:$m';
    }
    return '${minutes ?? 0} dk sonra';
  }
}
