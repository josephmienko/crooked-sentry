import Foundation

struct FrigateEvent: Codable {
    var id: String = ""
    var camera: String = ""
    var label: String = ""
    var score: Double = 0.0
    var startTime: Double = 0.0
    var endTime: Double? = nil
    var hasSnapshot: Bool = false
    var thumbnailPath: String? = nil
}
