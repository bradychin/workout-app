import Foundation
import SwiftData

@Observable
class WorkoutSession {

    struct LoggedSet: Identifiable {
        let id = UUID()
        var weight: Double
        var reps: Int
        var difficulty: Int
    }

    var activePlan: WorkoutPlan?
    var loggedSets: [PersistentIdentifier: [LoggedSet]] = [:]
    var startTime: Date = Date()
    var showWorkout: Bool = false

    var isActive: Bool { activePlan != nil }

    var totalSetsLogged: Int {
        loggedSets.values.reduce(0) { $0 + $1.count }
    }

    func start(plan: WorkoutPlan) {
        activePlan = plan
        loggedSets = [:]
        startTime = Date()
        showWorkout = true
    }

    func addSet(to planEx: PlanExercise, weight: Double, reps: Int, difficulty: Int) {
        let existing = loggedSets[planEx.persistentModelID] ?? []
        loggedSets[planEx.persistentModelID] = existing + [LoggedSet(weight: weight, reps: reps, difficulty: difficulty)]
    }

    func updateSet(for planEx: PlanExercise, at index: Int, weight: Double, reps: Int, difficulty: Int) {
        guard var sets = loggedSets[planEx.persistentModelID], sets.indices.contains(index) else { return }
        sets[index].weight = weight
        sets[index].reps = reps
        sets[index].difficulty = difficulty
        loggedSets[planEx.persistentModelID] = sets
    }

    func loggedSets(for planEx: PlanExercise) -> [LoggedSet] {
        loggedSets[planEx.persistentModelID] ?? []
    }

    func finish(context: ModelContext) {
        guard let plan = activePlan else { return }
        let now = Date()
        for planEx in plan.sortedExercises {
            guard let exercise = planEx.exercise,
                  let sets = loggedSets[planEx.persistentModelID] else { continue }
            for (index, set) in sets.enumerated() {
                let workoutSet = WorkoutSet(
                    date: now,
                    setNumber: index + 1,
                    reps: set.reps,
                    weight: set.weight,
                    difficulty: set.difficulty
                )
                workoutSet.exercise = exercise
                context.insert(workoutSet)
                exercise.sets.append(workoutSet)
            }
        }
        reset()
    }

    func reset() {
        activePlan = nil
        loggedSets = [:]
        showWorkout = false
    }
}
