/// The network through which the client is accessing the app.
enum NetworkType {
  /// Connected via local WiFi/LAN.
  wifi,

  /// Connected via WireGuard VPN.
  vpn,

  /// Connected from the public internet.
  other;

  /// Parse from the server's classification string.
  static NetworkType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'lan':
        return NetworkType.wifi;
      case 'vpn':
        return NetworkType.vpn;
      default:
        return NetworkType.other;
    }
  }

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case NetworkType.wifi:
        return 'Local Network';
      case NetworkType.vpn:
        return 'VPN';
      case NetworkType.other:
        return 'Internet';
    }
  }
}
