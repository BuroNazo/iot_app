import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import '../models/schedule.dart';
import 'schedule_evaluator.dart';

const String _relaySchedulesTaskName = 'relaySchedulesCheck';
const String _relaySchedulesUniqueName = 'relay-schedule-check';

// WorkManager'in her tetiklemede cagirdigi giris noktasi. Uygulama obfuscated
// olsa da veya Flutter 3.1+ ile calisirken bu pragma zorunludur.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _relaySchedulesTaskName) {
      await _runScheduleCheck();
    }
    return Future.value(true);
  });
}

Future<void> _runScheduleCheck() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final devicesEvent =
      await FirebaseDatabase.instance.ref('users/$uid/devices').once();
  final devicesSnap = devicesEvent.snapshot;
  if (!devicesSnap.exists) return;

  final now = NowInfo.fromDateTime(DateTime.now());
  final updates = <String, dynamic>{};

  final devicesData = devicesSnap.value as Map<dynamic, dynamic>;
  devicesData.forEach((deviceId, deviceValue) {
    if (deviceValue is! Map) return;
    final currentState = deviceValue['state'] as String?;
    final schedulesData = deviceValue['schedules'];
    if (schedulesData is! Map) return;

    schedulesData.forEach((scheduleId, scheduleValue) {
      if (scheduleValue is! Map) return;
      final schedule = Schedule.fromMap(scheduleId.toString(), scheduleValue);
      final result = evaluateSchedule(schedule, now);
      if (result.shouldTrigger) {
        final newCommand = toggleCommand(currentState);
        updates['users/$uid/devices/$deviceId/command'] = newCommand;
        result.scheduleUpdates.forEach((field, value) {
          updates['users/$uid/devices/$deviceId/schedules/$scheduleId/$field'] =
              value;
        });
      }
    });
  });

  if (updates.isNotEmpty) {
    await FirebaseDatabase.instance.ref().update(updates);
  }
}

Future<void> initializeBackgroundScheduler() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _relaySchedulesUniqueName,
    _relaySchedulesTaskName,
    frequency: const Duration(minutes: 15),
  );
}
