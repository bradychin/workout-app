import SwiftData
import Foundation

@Model
final class Exercise {
    var name: String
    var muscleGroup: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet] = []

    var isFavorite: Bool = false

    init(name: String, muscleGroup: String) {
        self.name = name
        self.muscleGroup = muscleGroup
    }

    var maxWeight: Double {
        sets.map(\.weight).max() ?? 0
    }

    var estimatedOneRM: Double {
        sets.map { set in
            guard set.reps > 0 else { return 0.0 }
            return set.weight * (1 + Double(set.reps) / 30.0)
        }.max() ?? 0
    }

    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
}
