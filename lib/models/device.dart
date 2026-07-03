class Device {
  final String id;
  final String name;
  final String state;
  final String command;
  final int lastSeen; // epoch ms (yeni firmware) veya 0/legacy-millis (eski)

  /// Bu sureden daha eski gorulen cihaz cevrimdisi sayilir.
  static const int onlineThresholdMs = 90 * 1000;

  /// Bundan kucuk lastSeen degerleri epoch olamaz (eski firmware millis()
  /// yazardi) — "hic gorulmedi" kabul edilir. 2001-09-09 epochu.
  static const int _minValidEpochMs = 1000000000000;

  Device({
    required this.id,
    required this.name,
    required this.state,
    required this.command,
    required this.lastSeen,
  });

  factory Device.fromMap(String id, Map<dynamic, dynamic> map) {
    return Device(
      id: id,
      name: map['name'] ?? 'ESP Cihaz',
      state: map['state'] ?? 'OFF',
      command: map['command'] ?? 'OFF',
      lastSeen: map['lastSeen'] ?? 0,
    );
  }

  bool get hasValidLastSeen => lastSeen >= _minValidEpochMs;

  bool isOnlineAt(int nowMs) =>
      hasValidLastSeen && nowMs - lastSeen < onlineThresholdMs;

  bool get isOnline => isOnlineAt(DateTime.now().millisecondsSinceEpoch);

  String lastSeenTextAt(int nowMs) {
    if (!hasValidLastSeen) return 'Bilinmiyor';
    final diff = nowMs - lastSeen;
    if (diff < 60 * 1000) return 'Simdi';
    if (diff < 60 * 60 * 1000) return '${diff ~/ (60 * 1000)} dk once';
    if (diff < 24 * 60 * 60 * 1000) {
      return '${diff ~/ (60 * 60 * 1000)} sa once';
    }
    return '${diff ~/ (24 * 60 * 60 * 1000)} gun once';
  }

  String get lastSeenText =>
      lastSeenTextAt(DateTime.now().millisecondsSinceEpoch);
}
