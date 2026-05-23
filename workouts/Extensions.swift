import Foundation

extension Double {
    /// "225" for whole numbers, "22.5" for decimals
    var formatted: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }

    /// "225 lbs" or "22.5 lbs"
    var lbs: String { "\(formatted) lbs" }
}
