import Foundation

struct ClimateState: Codable {
    var entityId: String = ""
    var state: String = ""
    var attributes: ClimateAttributes = ClimateAttributes()
    var lastChanged: Date = Date()
}

struct ClimateAttributes: Codable {
    var currentTemperature: Double = 0.0
    var temperature: Double = 0.0
    var targetTempHigh: Double? = nil
    var targetTempLow: Double? = nil
    var hvacModes: [String] = []
    var hvacAction: String = ""
    var friendlyName: String = ""
}
