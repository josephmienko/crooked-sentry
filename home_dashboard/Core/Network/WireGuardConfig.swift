import Foundation

struct WireGuardConfig: Codable {
    var privateKey: String = ""
    var publicKey: String = ""
    var endpoint: String = ""
    var allowedIPs: [String] = []
    var dns: String = ""
    var mtu: Int = 1420
    var persistentKeepalive: Int = 25
}
