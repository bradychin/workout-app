import SwiftData
import Foundation

@Model
final class PlanExercise {
    var targetSets: Int
    var targetReps: String
    var order: Int
    var exercise: Exercise?
    var plan: WorkoutPlan?

    init(targetSets: Int, targetReps: String, order: Int) {
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.order = order
    }

    var displayName: String {
        exercise?.name ?? "Unknown Exercise"
    }

    var targetDescription: String {
        "\(targetSets) × \(targetReps)"
    }
}
