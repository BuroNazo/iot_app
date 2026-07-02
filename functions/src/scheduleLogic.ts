export interface TimeSchedule {
  type: "time";
  enabled: boolean;
  hour: number;
  minute: number;
  days: number[]; // 1=Pzt ... 7=Paz
  lastTriggeredDate?: string; // "yyyy-MM-dd"
}

export interface CountdownSchedule {
  type: "countdown";
  enabled: boolean;
  minutes: number;
  triggerAt: number; // epoch ms
}

export type ScheduleData = TimeSchedule | CountdownSchedule;

export interface NowInfo {
  hour: number;
  minute: number;
  dayOfWeek: number; // 1=Pzt ... 7=Paz
  dateStr: string; // "yyyy-MM-dd"
  nowMs: number;
}

export interface EvaluationResult {
  shouldTrigger: boolean;
  scheduleUpdates: Record<string, unknown>;
}

export function evaluateSchedule(
  schedule: ScheduleData,
  now: NowInfo
): EvaluationResult {
  if (!schedule.enabled) {
    return { shouldTrigger: false, scheduleUpdates: {} };
  }

  if (schedule.type === "time") {
    const matchesTime =
      schedule.hour === now.hour && schedule.minute === now.minute;
    const matchesDay = schedule.days.includes(now.dayOfWeek);
    const alreadyTriggeredToday = schedule.lastTriggeredDate === now.dateStr;

    if (matchesTime && matchesDay && !alreadyTriggeredToday) {
      return {
        shouldTrigger: true,
        scheduleUpdates: { lastTriggeredDate: now.dateStr },
      };
    }
    return { shouldTrigger: false, scheduleUpdates: {} };
  }

  if (schedule.triggerAt <= now.nowMs) {
    return {
      shouldTrigger: true,
      scheduleUpdates: { enabled: false },
    };
  }
  return { shouldTrigger: false, scheduleUpdates: {} };
}

export function toggleCommand(currentState: string | undefined): "ON" | "OFF" {
  return currentState === "ON" ? "OFF" : "ON";
}
