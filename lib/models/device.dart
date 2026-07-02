class Device {
  final String id;
  final String name;
  final String state;
  final String command;
  final int lastSeen;

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
}
