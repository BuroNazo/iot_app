import 'package:flutter_test/flutter_test.dart';
import 'package:esp01_controller/models/device.dart';

void main() {
  // 2026-07-03 civari gercekci bir epoch-ms
  const nowMs = 1783100000000;

  Device device({int lastSeen = 0, String state = 'OFF'}) {
    return Device.fromMap('dev1', {
      'name': 'Test Cihaz',
      'state': state,
      'command': state,
      'lastSeen': lastSeen,
    });
  }

  group('Device.fromMap', () {
    test('parses fields with defaults', () {
      final d = Device.fromMap('abc', {});
      expect(d.id, 'abc');
      expect(d.name, 'ESP Cihaz');
      expect(d.state, 'OFF');
      expect(d.command, 'OFF');
      expect(d.lastSeen, 0);
    });
  });

  group('Device.isOnlineAt', () {
    test('online when lastSeen is within 90 seconds', () {
      final d = device(lastSeen: nowMs - 30 * 1000);
      expect(d.isOnlineAt(nowMs), true);
    });

    test('offline when lastSeen is older than 90 seconds', () {
      final d = device(lastSeen: nowMs - 120 * 1000);
      expect(d.isOnlineAt(nowMs), false);
    });

    test('offline when lastSeen is 0 (never seen)', () {
      final d = device(lastSeen: 0);
      expect(d.isOnlineAt(nowMs), false);
    });

    test('offline for legacy uptime-millis values (not epoch)', () {
      // Eski firmware millis() yazar: kucuk sayilar (< ~2001 epochu)
      final d = device(lastSeen: 393660);
      expect(d.isOnlineAt(nowMs), false);
    });
  });

  group('Device.lastSeenTextAt', () {
    test('reports unknown for 0 or legacy values', () {
      expect(device(lastSeen: 0).lastSeenTextAt(nowMs), 'Bilinmiyor');
      expect(device(lastSeen: 393660).lastSeenTextAt(nowMs), 'Bilinmiyor');
    });

    test('reports simdi within a minute', () {
      final d = device(lastSeen: nowMs - 20 * 1000);
      expect(d.lastSeenTextAt(nowMs), 'Simdi');
    });

    test('reports minutes ago', () {
      final d = device(lastSeen: nowMs - 5 * 60 * 1000);
      expect(d.lastSeenTextAt(nowMs), '5 dk once');
    });

    test('reports hours ago', () {
      final d = device(lastSeen: nowMs - 3 * 60 * 60 * 1000);
      expect(d.lastSeenTextAt(nowMs), '3 sa once');
    });
  });
}
