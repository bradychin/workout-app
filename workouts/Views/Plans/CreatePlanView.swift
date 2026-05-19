import SwiftUI
import SwiftData

struct CreatePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.muscleGroup) private var exercises: [Exercise]

    @State private var planName = ""
    @State private var selectedExercises: [(Exercise, Int, String)] = [] // (exercise, sets, reps)
    @State private var showExercisePicker = false

    private var grouped: [(String, [Exercise])] {
        let dict = Dictionary(grouping: exercises) { $0.muscleGroup }
        return dict.map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Name") {
                    TextField("e.g. Push Day", text: $planName)
                }

                Section {
                    ForEach(Array(selectedExercises.enumerated()), id: \.offset) { index, item in
                        ExercisePlanRow(
                            exercise: item.0,
                            sets: Binding(
                                get: { selectedExercises[index].1 },
                                set: { selectedExercises[index].1 = $0 }
                            ),
                            reps: Binding(
                                get: { selectedExercises[index].2 },
                                set: { selectedExercises[index].2 = $0 }
                            )
                        )
                    }
                    .onDelete { offsets in
                        selectedExercises.remove(atOffsets: offsets)
                    }
                    .onMove { from, to in
                        selectedExercises.move(fromOffsets: from, toOffset: to)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle")
                            .foregroundStyle(.indigo)
                    }
                } header: {
                    Text("Exercises")
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePlan() }
                        .disabled(planName.trimmingCharacters(in: .whitespaces).isEmpty || selectedExercises.isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(
                    grouped: grouped,
                    selected: Set(selectedExercises.map { $0.0.persistentModelID })
                ) { exercise in
                    if !selectedExercises.contains(where: { $0.0.persistentModelID == exercise.persistentModelID }) {
                        selectedExercises.append((exercise, 3, "8-12"))
                    }
                }
            }
        }
    }

    private func savePlan() {
        let plan = WorkoutPlan(name: planName.trimmingCharacters(in: .whitespaces))
        modelContext.insert(plan)

        for (index, (exercise, sets, reps)) in selectedExercises.enumerated() {
            let planEx = PlanExercise(targetSets: sets, targetReps: reps, order: index)
            planEx.plan = plan
            planEx.exercise = exercise
            modelContext.insert(planEx)
            plan.planExercises.append(planEx)
        }

        dismiss()
    }
}

struct ExercisePlanRow: View {
    let exercise: Exercise
    @Binding var sets: Int
    @Binding var reps: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.body)
                .fontWeight(.medium)

            HStack(spacing: 16) {
                HStack {
                    Text("Sets:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(sets)", value: $sets, in: 1...20)
                        .labelsHidden()
                    Text("\(sets)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 20)
                }

                HStack {
                    Text("Reps:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("8-12", text: $reps)
                        .font(.caption)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct ExercisePickerView: View {
    let grouped: [(String, [Exercise])]
    let selected: Set<PersistentIdentifier>
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredGrouped: [(String, [Exercise])] {
        if searchText.isEmpty { return grouped }
        return grouped.compactMap { group, exercises in
            let filtered = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            return filtered.isEmpty ? nil : (group, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGrouped, id: \.0) { group, exercises in
                    Section(group) {
                        ForEach(exercises) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selected.contains(exercise.persistentModelID) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.indigo)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CreatePlanView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
}
