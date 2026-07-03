import {
  evaluateSchedule,
  toggleCommand,
  NowInfo,
  TimeSchedule,
  CountdownSchedule,
} from "./scheduleLogic";

const now = (overrides: Partial<NowInfo> = {}): NowInfo => ({
  hour: 22,
  minute: 30,
  dayOfWeek: 3, // Çarşamba
  dateStr: "2026-07-02",
  nowMs: 1751450000000,
  ...overrides,
});

describe("evaluateSchedule - time type", () => {
  const base: TimeSchedule = {
    type: "time",
    enabled: true,
    hour: 22,
    minute: 30,
    days: [3, 4, 5],
  };

  test("triggers when hour, minute and day match and not already triggered today", () => {
    const result = evaluateSchedule(base, now());
    expect(result.shouldTrigger).toBe(true);
    expect(result.scheduleUpdates).toEqual({ lastTriggeredDate: "2026-07-02" });
  });

  test("does not trigger when current time is before the scheduled time", () => {
    const result = evaluateSchedule(base, now({ minute: 29 }));
    expect(result.shouldTrigger).toBe(false);
  });

  test("triggers (catch-up) when current time is after the scheduled time and not already triggered today", () => {
    // GitHub Actions cron does not run every minute reliably, so a check
    // that happens well after the scheduled minute must still fire once.
    const result = evaluateSchedule(base, now({ hour: 23, minute: 45 }));
    expect(result.shouldTrigger).toBe(true);
    expect(result.scheduleUpdates).toEqual({ lastTriggeredDate: "2026-07-02" });
  });

  test("does not trigger when day is not in days list", () => {
    const result = evaluateSchedule(base, now({ dayOfWeek: 1 }));
    expect(result.shouldTrigger).toBe(false);
  });

  test("does not trigger twice on the same day", () => {
    const schedule: TimeSchedule = { ...base, lastTriggeredDate: "2026-07-02" };
    const result = evaluateSchedule(schedule, now());
    expect(result.shouldTrigger).toBe(false);
  });

  test("does not trigger when disabled", () => {
    const schedule: TimeSchedule = { ...base, enabled: false };
    const result = evaluateSchedule(schedule, now());
    expect(result.shouldTrigger).toBe(false);
  });
});

describe("evaluateSchedule - countdown type", () => {
  const base: CountdownSchedule = {
    type: "countdown",
    enabled: true,
    minutes: 15,
    triggerAt: 1751450000000,
  };

  test("triggers and disables itself when triggerAt has passed", () => {
    const result = evaluateSchedule(base, now({ nowMs: 1751450000001 }));
    expect(result.shouldTrigger).toBe(true);
    expect(result.scheduleUpdates).toEqual({ enabled: false });
  });

  test("does not trigger when triggerAt is in the future", () => {
    const result = evaluateSchedule(base, now({ nowMs: 1751449999999 }));
    expect(result.shouldTrigger).toBe(false);
  });
});

describe("toggleCommand", () => {
  test("returns OFF when current state is ON", () => {
    expect(toggleCommand("ON")).toBe("OFF");
  });

  test("returns ON when current state is OFF or undefined", () => {
    expect(toggleCommand("OFF")).toBe("ON");
    expect(toggleCommand(undefined)).toBe("ON");
  });
});
