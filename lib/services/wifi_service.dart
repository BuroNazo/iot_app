import 'package:wifi_scan/wifi_scan.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/wifi_network.dart';

class WifiService {
  final _networkInfo = NetworkInfo();

  // ESP AP adı — Arduino kodundaki AP_SSID ile aynı olmalı
  static const String espApName = 'OZDSOFT_ESPSetup';

  Future<bool> requestPermissions() async {
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) return false;
    await Permission.nearbyWifiDevices.request();
    return true;
  }

  Future<List<WifiNetwork>> scan() async {
    try {
      final serviceEnabled = await Permission.location.serviceStatus.isEnabled;
      if (!serviceEnabled) return [];

      final canStart = await WiFiScan.instance.canStartScan();
      if (canStart == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await Future.delayed(const Duration(seconds: 2));
      }

      final canGet = await WiFiScan.instance.canGetScannedResults(
        askPermissions: true,
      );
      if (canGet != CanGetScannedResults.yes) return [];

      final results = await WiFiScan.instance.getScannedResults();

      return results
          .map<WifiNetwork>((res) => WifiNetwork(
                ssid: res.ssid,
                level: res.level,
                isSecure: res.capabilities.contains('WPA') ||
                    res.capabilities.contains('WEP'),
              ))
          .where((n) => n.ssid.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.level.compareTo(a.level));
    } catch (e) {
      return [];
    }
  }

  // WiFi ayarlarını aç
  Future<void> openWifiSettings() async {
    await openAppSettings();
  }

  // Konum ayarlarını aç
  Future<void> openLocationSettings() async {
    await openAppSettings();
  }

  Future<String?> getCurrentSSID() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      return ssid?.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  // ESP Setup AP'sine bağlı mı kontrol et
  Future<bool> isConnectedToSetupAP() async {
    final ssid = await getCurrentSSID();
    return ssid == espApName; // ← OZDSOFT_ESPSetup
  }

  void dispose() {}
}
