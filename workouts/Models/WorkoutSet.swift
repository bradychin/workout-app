import SwiftData
import Foundation

@Model
final class WorkoutSet {
    var date: Date
    var setNumber: Int
    var reps: Int
    var weight: Double
    var difficulty: Int
    var exercise: Exercise?

    init(date: Date, setNumber: Int, reps: Int, weight: Double, difficulty: Int) {
        self.date = date
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.difficulty = difficulty
    }

    var volume: Double {
        weight * Double(reps)
    }

    var estimatedOneRM: Double {
        guard reps > 0 else { return 0 }
        return weight * (1 + Double(reps) / 30.0)
    }
}
