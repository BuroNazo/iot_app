import * as admin from "firebase-admin";
import { DateTime } from "luxon";
import {
  evaluateSchedule,
  toggleCommand,
  ScheduleData,
  NowInfo,
} from "./scheduleLogic";

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
  });
}

function buildNowInfo(): NowInfo {
  const now = DateTime.now().setZone("Europe/Istanbul");
  return {
    hour: now.hour,
    minute: now.minute,
    dayOfWeek: now.weekday, // luxon: 1=Pazartesi ... 7=Pazar
    dateStr: now.toFormat("yyyy-MM-dd"),
    nowMs: Date.now(),
  };
}

// GitHub Actions cron tarafından çağrılan tek seferlik çalıştırma.
// Firebase Cloud Functions (Blaze plan) gerektirmez — standart bir Node
// script olarak GOOGLE_APPLICATION_CREDENTIALS ile kimlik doğrular.
export async function runSchedulesOnce(): Promise<void> {
  const db = admin.database();
  const usersSnap = await db.ref("users").once("value");
  if (!usersSnap.exists()) return;

  const nowInfo = buildNowInfo();
  const updates: Record<string, unknown> = {};

  usersSnap.forEach((userSnap) => {
    const uid = userSnap.key;
    const devices = userSnap.child("devices");
    devices.forEach((deviceSnap) => {
      const deviceId = deviceSnap.key;
      const currentState = deviceSnap.child("state").val() as
        | string
        | undefined;
      const schedules = deviceSnap.child("schedules");
      schedules.forEach((scheduleSnap) => {
        const scheduleId = scheduleSnap.key;
        const schedule = scheduleSnap.val() as ScheduleData;
        const result = evaluateSchedule(schedule, nowInfo);
        if (result.shouldTrigger) {
          const newCommand = toggleCommand(currentState);
          updates[`users/${uid}/devices/${deviceId}/command`] = newCommand;
          for (const [field, value] of Object.entries(result.scheduleUpdates)) {
            updates[
              `users/${uid}/devices/${deviceId}/schedules/${scheduleId}/${field}`
            ] = value;
          }
        }
        return false;
      });
      return false;
    });
    return false;
  });

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
  }
}

if (require.main === module) {
  runSchedulesOnce()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
