import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/schedule.dart';

class ScheduleService {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DatabaseReference _schedulesRef(String deviceId) => FirebaseDatabase.instance
      .ref("users/$_uid/devices/$deviceId/schedules");

  Stream<List<Schedule>> schedulesStream(String deviceId) {
    return _schedulesRef(deviceId).onValue.map((event) {
      if (!event.snapshot.exists) return <Schedule>[];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final schedules = <Schedule>[];
      data.forEach((key, value) {
        if (value is Map) {
          schedules.add(Schedule.fromMap(key.toString(), value));
        }
      });
      return schedules;
    });
  }

  Future<void> addTimeSchedule(
    String deviceId, {
    required int hour,
    required int minute,
    required List<int> days,
  }) async {
    final ref = _schedulesRef(deviceId).push();
    await ref.set({
      'type': 'time',
      'enabled': true,
      'hour': hour,
      'minute': minute,
      'days': days,
      'lastTriggeredDate': '',
    });
  }

  Future<void> addCountdownSchedule(
    String deviceId, {
    required int minutes,
  }) async {
    final ref = _schedulesRef(deviceId).push();
    final triggerAt =
        DateTime.now().millisecondsSinceEpoch + minutes * 60 * 1000;
    await ref.set({
      'type': 'countdown',
      'enabled': true,
      'minutes': minutes,
      'triggerAt': triggerAt,
    });
  }

  Future<void> setEnabled(
      String deviceId, String scheduleId, bool enabled) async {
    await _schedulesRef(deviceId).child(scheduleId).update({'enabled': enabled});
  }

  Future<void> deleteSchedule(String deviceId, String scheduleId) async {
    await _schedulesRef(deviceId).child(scheduleId).remove();
  }
}
