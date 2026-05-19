import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    let plan: WorkoutPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var loggedSets: [PersistentIdentifier: [LoggedSet]] = [:]
    @State private var loggingFor: PlanExercise?
    @State private var historyFor: Exercise?
    @State private var startTime = Date()
    @State private var showFinishConfirm = false

    struct LoggedSet: Identifiable {
        let id = UUID()
        var weight: Double
        var reps: Int
        var difficulty: Int
    }

    private var sortedExercises: [PlanExercise] {
        plan.sortedExercises
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Timer
                    workoutTimerBanner

                    // Exercise cards
                    ForEach(sortedExercises) { planEx in
                        ActiveExerciseCard(
                            planExercise: planEx,
                            loggedSets: loggedSets[planEx.persistentModelID] ?? [],
                            onAddSet: { loggingFor = planEx },
                            onViewHistory: { historyFor = planEx.exercise }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        showFinishConfirm = true
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo)
                }
            }
            .sheet(item: $historyFor) { exercise in
                ExerciseHistorySheet(exercise: exercise)
            }
            .sheet(item: $loggingFor) { planEx in
                InlineSetLogger(
                    exerciseName: planEx.exercise?.name ?? "Exercise",
                    lastWeight: lastWeight(for: planEx),
                    lastReps: lastReps(for: planEx)
                ) { weight, reps, difficulty in
                    addSet(to: planEx, weight: weight, reps: reps, difficulty: difficulty)
                }
            }
            .confirmationDialog("Finish Workout?", isPresented: $showFinishConfirm) {
                Button("Save & Finish", role: .none) { saveWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save all logged sets to your history?")
            }
        }
    }

    // MARK: - Helper Views

    private var workoutTimerBanner: some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout in Progress")
                        .font(.headline)
                    Text(startTime, style: .timer)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.indigo)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Logic

    private func lastWeight(for planEx: PlanExercise) -> Double {
        guard let exercise = planEx.exercise else { return 0 }
        return exercise.sets.sorted { $0.date > $1.date }.first?.weight ?? 0
    }

    private func lastReps(for planEx: PlanExercise) -> Int {
        guard let exercise = planEx.exercise else { return 0 }
        return exercise.sets.sorted { $0.date > $1.date }.first?.reps ?? 0
    }

    private func addSet(to planEx: PlanExercise, weight: Double, reps: Int, difficulty: Int) {
        let existing = loggedSets[planEx.persistentModelID] ?? []
        let newSet = LoggedSet(weight: weight, reps: reps, difficulty: difficulty)
        loggedSets[planEx.persistentModelID] = existing + [newSet]
    }

    private func saveWorkout() {
        let now = Date()
        for planEx in sortedExercises {
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
                modelContext.insert(workoutSet)
                exercise.sets.append(workoutSet)
            }
        }
        dismiss()
    }
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let planExercise: PlanExercise
    let loggedSets: [ActiveWorkoutView.LoggedSet]
    let onAddSet: () -> Void
    let onViewHistory: () -> Void

    private var targetSets: Int { planExercise.targetSets }
    private var setsLogged: Int { loggedSets.count }
    private var isComplete: Bool { setsLogged >= targetSets }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planExercise.exercise?.name ?? "Unknown")
                            .font(.headline)
                        Text("Target: \(planExercise.targetDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onViewHistory) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.title3)
                            .foregroundStyle(.indigo)
                            .padding(6)
                            .background(Color.indigo.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                }

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<targetSets, id: \.self) { setIndex in
                        Circle()
                            .fill(setIndex < setsLogged ? Color.indigo : Color(.systemFill))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(setIndex < setsLogged ? Color.indigo : Color(.separator), lineWidth: 1)
                            )
                    }
                    Spacer()
                    Text("\(setsLogged)/\(targetSets)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isComplete ? .green : .secondary)
                }

                // Logged sets
                if !loggedSets.isEmpty {
                    Divider()
                    VStack(spacing: 6) {
                        ForEach(Array(loggedSets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .leading)
                                Text("\(Int(set.weight)) lbs × \(set.reps) reps")
                                    .font(.subheadline)
                                Spacer()
                                DifficultyBadge(difficulty: set.difficulty)
                            }
                        }
                    }
                }

                // Add set button
                Button(action: onAddSet) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(setsLogged == 0 ? "Log First Set" : "Log Set \(setsLogged + 1)")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isComplete ? Color(.systemFill) : Color.indigo)
                    .foregroundStyle(isComplete ? Color.secondary : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: Int

    var color: Color {
        switch difficulty {
        case 1...4: return .green
        case 5...7: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text("RPE \(difficulty)")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Inline Set Logger

struct InlineSetLogger: View {
    let exerciseName: String
    let lastWeight: Double
    let lastReps: Int
    let onSave: (Double, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double
    @State private var reps: Int
    @State private var difficulty: Int = 7

    init(exerciseName: String, lastWeight: Double, lastReps: Int, onSave: @escaping (Double, Int, Int) -> Void) {
        self.exerciseName = exerciseName
        self.lastWeight = lastWeight
        self.lastReps = lastReps
        self.onSave = onSave
        self._weight = State(initialValue: lastWeight > 0 ? lastWeight : 45)
        self._reps = State(initialValue: lastReps > 0 ? lastReps : 10)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Exercise name
                Text(exerciseName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                // Weight picker
                VStack(spacing: 8) {
                    Text("Weight (lbs)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 20) {
                        Button {
                            weight = max(0, weight - 5)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)

                        Text(String(format: "%.1f", weight))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .frame(minWidth: 120, alignment: .center)

                        Button {
                            weight += 5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)
                    }

                    // Fine control
                    HStack(spacing: 8) {
                        ForEach([2.5, 1.25, 0.5], id: \.self) { delta in
                            Button("-\(delta, specifier: "%.2g")") {
                                weight = max(0, weight - delta)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                            .buttonStyle(.plain)

                            Button("+\(delta, specifier: "%.2g")") {
                                weight += delta
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Reps picker
                VStack(spacing: 8) {
                    Text("Reps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 20) {
                        Button {
                            reps = max(1, reps - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)

                        Text("\(reps)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .frame(minWidth: 80, alignment: .center)

                        Button {
                            reps += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Difficulty / RPE
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Difficulty (RPE)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(difficulty)/10")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Slider(value: Binding(
                        get: { Double(difficulty) },
                        set: { difficulty = Int($0) }
                    ), in: 1...10, step: 1)
                    .tint(.indigo)
                }
                .padding(.horizontal)

                Spacer()

                // Save button
                Button {
                    onSave(weight, reps, difficulty)
                    dismiss()
                } label: {
                    Text("Save Set")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Exercise History Sheet

struct ExerciseHistorySheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    private var recentSessions: [(Date, [WorkoutSet])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: exercise.sets) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.setNumber < $1.setNumber }) }
            .sorted { $0.0 > $1.0 }
            .prefix(5)
            .map { $0 }
    }

    private var maxWeightEver: Double { exercise.sets.map(\.weight).max() ?? 0 }
    private var bestOneRM: Double { exercise.sets.map(\.estimatedOneRM).max() ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats bar
                    if maxWeightEver > 0 {
                        HStack(spacing: 0) {
                            statPill(label: "Max Weight", value: String(format: "%.0f lbs", maxWeightEver))
                            Divider().frame(height: 36)
                            statPill(label: "Best Est. 1RM", value: String(format: "%.0f lbs", bestOneRM))
                            Divider().frame(height: 36)
                            statPill(label: "Total Sets", value: "\(exercise.sets.count)")
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    if recentSessions.isEmpty {
                        ContentUnavailableView(
                            "No History",
                            systemImage: "clock",
                            description: Text("No sets logged yet for this exercise")
                        )
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(recentSessions, id: \.0) { date, sets in
                                sessionCard(date: date, sets: sets)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.indigo)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func sessionCard(date: Date, sets: [WorkoutSet]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                let sessionVolume = sets.reduce(0.0) { $0 + $1.volume }
                Text(String(format: "%.0f lbs vol", sessionVolume))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(sets) { set in
                    HStack {
                        Text("Set \(set.setNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        Text(String(format: "%.0f lbs × %d reps", set.weight, set.reps))
                            .font(.subheadline)
                        Spacer()
                        DifficultyBadge(difficulty: set.difficulty)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ActiveWorkoutView(plan: {
        let p = WorkoutPlan(name: "Push Day")
        return p
    }())
    .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
}
