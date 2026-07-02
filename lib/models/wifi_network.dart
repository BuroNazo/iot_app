class WifiNetwork {
  final String ssid;
  final int level;
  final bool isSecure;

  WifiNetwork({
    required this.ssid,
    required this.level,
    this.isSecure = true,
  });

  // Signal strength percentage calculation
  int get signalStrength {
    if (level <= -100) return 0;
    if (level >= -50) return 100;
    return 2 * (level + 100);
  }
}
