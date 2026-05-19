import SwiftData
import Foundation

@Model
final class WorkoutPlan {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.plan)
    var planExercises: [PlanExercise] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }

    var sortedExercises: [PlanExercise] {
        planExercises.sorted { $0.order < $1.order }
    }
}
