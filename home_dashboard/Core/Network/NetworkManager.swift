import Foundation

class NetworkManager {
    var baseURL: URL = URL(string: "http://192.168.0.200")!
    
    // Stub methods
    func checkNetworkStatus() async -> NetworkStatus { 
        return NetworkStatus(network: .lan, ip: "192.168.0.200") 
    }
    
    func ensureConnected() async throws {
        // Will activate VPN if not on LAN
    }
    
    func request<T>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T { 
        throw NSError() 
    }
}
