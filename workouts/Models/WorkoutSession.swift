import Foundation
import SwiftData

@Observable
class WorkoutSession {

    struct LoggedSet: Identifiable, Codable {
        var id = UUID()
        var weight: Double
        var reps: Int
        var difficulty: Int

        enum CodingKeys: String, CodingKey {
            case weight, reps, difficulty
        }
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
        saveDraft()
    }

    func addSet(to planEx: PlanExercise, weight: Double, reps: Int, difficulty: Int) {
        let existing = loggedSets[planEx.persistentModelID] ?? []
        loggedSets[planEx.persistentModelID] = existing + [LoggedSet(weight: weight, reps: reps, difficulty: difficulty)]
        saveDraft()
    }

    func updateSet(for planEx: PlanExercise, at index: Int, weight: Double, reps: Int, difficulty: Int) {
        guard var sets = loggedSets[planEx.persistentModelID], sets.indices.contains(index) else { return }
        sets[index].weight = weight
        sets[index].reps = reps
        sets[index].difficulty = difficulty
        loggedSets[planEx.persistentModelID] = sets
        saveDraft()
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
        // Saved explicitly so the workout is on disk before the draft is cleared;
        // autosave alone can lose it if the app is killed right after finishing.
        try? context.save()
        reset()
    }

    func reset() {
        activePlan = nil
        loggedSets = [:]
        showWorkout = false
        clearDraft()
    }

    // MARK: - Interrupted workout recovery

    private static let draftKey = "activeWorkoutDraft"

    // Sets are keyed by PlanExercise.order rather than persistentModelID: a decoded
    // PersistentIdentifier compares equal to its live counterpart but hashes
    // differently, so it silently misses as a dictionary key.
    private struct Draft: Codable {
        var planID: PersistentIdentifier
        var setsByExerciseOrder: [Int: [LoggedSet]]
        var startTime: Date
    }

    private func saveDraft() {
        guard let plan = activePlan else { return }
        var byOrder: [Int: [LoggedSet]] = [:]
        for planEx in plan.sortedExercises {
            if let sets = loggedSets[planEx.persistentModelID], !sets.isEmpty {
                byOrder[planEx.order] = sets
            }
        }
        let draft = Draft(
            planID: plan.persistentModelID,
            setsByExerciseOrder: byOrder,
            startTime: startTime
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftKey)
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }

    func restoreDraft(context: ModelContext) {
        guard activePlan == nil,
              let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let draft = try? JSONDecoder().decode(Draft.self, from: data)
        else { return }

        // Matched against a fetch rather than context.model(for:) so a since-deleted
        // plan yields nil instead of trapping on an invalidated instance.
        let plans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        guard let plan = plans.first(where: { $0.persistentModelID == draft.planID }) else {
            clearDraft()
            return
        }

        var restored: [PersistentIdentifier: [LoggedSet]] = [:]
        for planEx in plan.sortedExercises {
            if let sets = draft.setsByExerciseOrder[planEx.order] {
                restored[planEx.persistentModelID] = sets
            }
        }

        activePlan = plan
        loggedSets = restored
        startTime = draft.startTime
        // showWorkout stays false so the banner offers to resume instead of
        // forcing the sheet open at launch.
    }
}
