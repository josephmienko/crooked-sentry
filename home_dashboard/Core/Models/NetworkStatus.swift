import Foundation

enum NetworkType: String, Codable {
    case lan
    case vpn
    case internet
}

struct NetworkStatus: Codable {
    var network: NetworkType = .lan
    var ip: String = ""
}
