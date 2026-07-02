import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EspService {
  static const String setupIp = "192.168.4.1";

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _basePath => "users/$_uid/devices";

  DatabaseReference deviceRef(String deviceId) =>
      FirebaseDatabase.instance.ref("$_basePath/$deviceId");

  Future<void> init() async {}

  String _sanitizeName(String name) {
    const turkish = [
      'ğ',
      'Ğ',
      'ü',
      'Ü',
      'ş',
      'Ş',
      'ı',
      'İ',
      'ö',
      'Ö',
      'ç',
      'Ç'
    ];
    const ascii = ['g', 'G', 'u', 'U', 's', 'S', 'i', 'I', 'o', 'O', 'c', 'C'];
    String result = name;
    for (int i = 0; i < turkish.length; i++) {
      result = result.replaceAll(turkish[i], ascii[i]);
    }
    return result;
  }

  // ESP'ye WiFi + isim + UID gönder
  // ESP kendi MAC'iyle Firebase'e kaydeder
  Future<bool> provision(String ssid, String password,
      [String name = "ESP Cihaz"]) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$setupIp/wifi'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ssid': ssid,
              'password': password,
              'name': _sanitizeName(name),
              'uid': _uid,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return false;

      // ESP'nin WiFi'a bağlanıp Firebase'e yazmasını bekle
      await Future.delayed(const Duration(seconds: 15));

      // Firebase'de cihaz göründü mü kontrol et
      final snapshot =
          await FirebaseDatabase.instance.ref("users/$_uid/devices").once();

      return snapshot.snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // Firebase üzerinden röle aç/kapat
  Future<bool> toggleRelay(String deviceId, bool status) async {
    try {
      await deviceRef(deviceId).update({'command': status ? 'ON' : 'OFF'});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Röle durumunu dinle
  Stream<bool> relayStateStream(String deviceId) {
    return deviceRef(deviceId)
        .child('state')
        .onValue
        .map((event) => event.snapshot.value == 'ON');
  }

  Future<bool> getRelayStatus(String deviceId) async {
    try {
      final event = await deviceRef(deviceId).child('state').once();
      return event.snapshot.value == 'ON';
    } catch (_) {
      return false;
    }
  }

  // Firebase üzerinden reset komutu gönder
  Future<bool> resetDevice(String deviceId) async {
    try {
      await deviceRef(deviceId).update({'command': 'RESET'});
      await Future.delayed(const Duration(seconds: 6));
      await deviceRef(deviceId).update({'command': 'OFF', 'state': 'OFF'});
      return true;
    } catch (e) {
      return false;
    }
  }

  // Cihazı sil (ESP reset + Firebase'den kaldır)
  Future<void> deleteDevice(String deviceId) async {
    try {
      await deviceRef(deviceId).update({'command': 'RESET'});
      await Future.delayed(const Duration(seconds: 6));
    } catch (_) {}
    await deviceRef(deviceId).remove();
  }

  Future<void> updateDeviceIp(String ip) async {}
}
