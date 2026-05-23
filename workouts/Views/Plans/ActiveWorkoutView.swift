import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(WorkoutSession.self) private var workoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var loggingFor: PlanExercise?
    @State private var editingSet: EditSetTarget?
    @State private var historyFor: Exercise?
    @State private var showCancelConfirm = false
    @State private var showFinishConfirm = false

    struct EditSetTarget: Identifiable {
        let id = UUID()
        let planEx: PlanExercise
        let index: Int
        let set: WorkoutSession.LoggedSet
    }

    private var plan: WorkoutPlan? { workoutSession.activePlan }

    var body: some View {
        @Bindable var session = workoutSession

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    workoutTimerBanner

                    if let plan {
                        ForEach(plan.sortedExercises) { planEx in
                            ActiveExerciseCard(
                                planExercise: planEx,
                                loggedSets: workoutSession.loggedSets(for: planEx),
                                onAddSet: { loggingFor = planEx },
                                onEditSet: { index in
                                    let sets = workoutSession.loggedSets(for: planEx)
                                    guard sets.indices.contains(index) else { return }
                                    editingSet = EditSetTarget(planEx: planEx, index: index, set: sets[index])
                                },
                                onViewHistory: { historyFor = planEx.exercise }
                            )
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .navigationTitle(plan?.name ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCancelConfirm = true }
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { showFinishConfirm = true }
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                }
            }
            .sheet(item: $historyFor) { exercise in
                ExerciseHistorySheet(exercise: exercise)
            }
            .sheet(item: $editingSet) { target in
                InlineSetLogger(
                    exerciseName: target.planEx.exercise?.name ?? "Exercise",
                    title: "Edit Set \(target.index + 1)",
                    lastWeight: target.set.weight,
                    lastReps: target.set.reps,
                    lastDifficulty: target.set.difficulty
                ) { weight, reps, difficulty in
                    workoutSession.updateSet(for: target.planEx, at: target.index, weight: weight, reps: reps, difficulty: difficulty)
                }
            }
            .sheet(item: $loggingFor) { planEx in
                let setNumber = workoutSession.loggedSets(for: planEx).count + 1
                InlineSetLogger(
                    exerciseName: planEx.exercise?.name ?? "Exercise",
                    title: "Log Set \(setNumber)",
                    lastWeight: lastWeight(for: planEx),
                    lastReps: lastReps(for: planEx)
                ) { weight, reps, difficulty in
                    workoutSession.addSet(to: planEx, weight: weight, reps: reps, difficulty: difficulty)
                }
            }
            .confirmationDialog("Cancel Workout?", isPresented: $showCancelConfirm) {
                Button("Discard Workout", role: .destructive) {
                    workoutSession.reset()
                    dismiss()
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("All logged sets will be lost.")
            }
            .confirmationDialog("Finish Workout?", isPresented: $showFinishConfirm) {
                Button("Save & Finish") {
                    workoutSession.finish(context: modelContext)
                    dismiss()
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Save all \(workoutSession.totalSetsLogged) logged sets to your history?")
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Timer banner

    private var workoutTimerBanner: some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout in Progress")
                        .font(.headline)
                    Text(workoutSession.startTime, style: .timer)
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

    // MARK: - Helpers

    private func lastWeight(for planEx: PlanExercise) -> Double {
        planEx.exercise?.sets.sorted { $0.date > $1.date }.first?.weight ?? 0
    }

    private func lastReps(for planEx: PlanExercise) -> Int {
        planEx.exercise?.sets.sorted { $0.date > $1.date }.first?.reps ?? 0
    }
}

// MARK: - Active Exercise Card

struct ActiveExerciseCard: View {
    let planExercise: PlanExercise
    let loggedSets: [WorkoutSession.LoggedSet]
    let onAddSet: () -> Void
    let onEditSet: (Int) -> Void
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
                                Text("\(set.weight.lbs) × \(set.reps) reps")
                                    .font(.subheadline)
                                Spacer()
                                DifficultyBadge(difficulty: set.difficulty)
                                Button {
                                    onEditSet(index)
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(6)
                                        .background(Color(.systemFill))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
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

// MARK: - Difficulty Badge

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
    let title: String
    let lastWeight: Double
    let lastReps: Int
    let lastDifficulty: Int
    let onSave: (Double, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double
    @State private var reps: Int
    @State private var difficulty: Int

    init(exerciseName: String, title: String = "Log Set", lastWeight: Double, lastReps: Int, lastDifficulty: Int = 7, onSave: @escaping (Double, Int, Int) -> Void) {
        self.exerciseName = exerciseName
        self.title = title
        self.lastWeight = lastWeight
        self.lastReps = lastReps
        self.lastDifficulty = lastDifficulty
        self.onSave = onSave
        self._weight = State(initialValue: lastWeight > 0 ? lastWeight : 45)
        self._reps = State(initialValue: lastReps > 0 ? lastReps : 10)
        self._difficulty = State(initialValue: lastDifficulty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(spacing: 24) {
                // Weight picker
                VStack(spacing: 8) {
                    Text("Weight (lbs)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 20) {
                        Button { weight = max(0, weight - 1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)

                        Text(weight.formatted)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .frame(minWidth: 120, alignment: .center)

                        Button { weight += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        ForEach([0.5, 5, 10], id: \.self) { delta in
                            Button("-\(delta, specifier: "%.2g")") { weight = max(0, weight - delta) }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                                .buttonStyle(.plain)

                            Button("+\(delta, specifier: "%.2g")") { weight += delta }
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
                        Button { reps = max(1, reps - 1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)

                        Text("\(reps)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .frame(minWidth: 80, alignment: .center)

                        Button { reps += 1 } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // RPE
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
              }
              .padding(.horizontal)
              .padding(.top, 8)
              .padding(.bottom, 12)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onSave(weight, reps, difficulty)
                    dismiss()
                } label: {
                    Text(title.hasPrefix("Edit") ? "Save Changes" : "Save Set")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
        .presentationDetents([.large])
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
                    if maxWeightEver > 0 {
                        HStack(spacing: 0) {
                            statPill(label: "Max Weight", value: maxWeightEver.lbs)
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
                        ContentUnavailableView("No History", systemImage: "clock",
                            description: Text("No sets logged yet"))
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
                                Text("\(set.weight.lbs) × \(set.reps) reps")
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
    ActiveWorkoutView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
        .environment(WorkoutSession())
}
