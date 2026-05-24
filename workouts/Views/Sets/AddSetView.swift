import SwiftUI
import SwiftData

struct AddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.muscleGroup) private var exercises: [Exercise]

    var preselectedExercise: Exercise?

    @State private var selectedExercise: Exercise?
    @State private var weight: Double = 45
    @State private var weightText: String = "45"
    @State private var reps: Int = 10
    @State private var difficulty: Int = 7
    @State private var date: Date = Date()
    @State private var showExerciseSearch = false
    @FocusState private var weightFocused: Bool

    init(preselectedExercise: Exercise? = nil) {
        self.preselectedExercise = preselectedExercise
    }

    var body: some View {
        NavigationStack {
            Form {
                // Exercise picker
                Section("Exercise") {
                    Button {
                        showExerciseSearch = true
                    } label: {
                        HStack {
                            Text(selectedExercise?.name ?? "Select Exercise")
                                .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Weight
                Section("Weight (lbs)") {
                    VStack(spacing: 6) {
                        SetWeightView(weight: $weight,
                                      fontSize: 34,
                                      cardWidth: 160,
                                      verticalPadding: 8,
                                      horizontalPadding: 16)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Reps
                Section("Reps") {
                    Stepper("\(reps) reps", value: $reps, in: 1...100)
                }

                // Difficulty
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RPE")
                            Spacer()
                            Text("\(difficulty)/10")
                                .fontWeight(.semibold)
                                .foregroundStyle(.indigo)
                        }
                        Slider(value: Binding(
                            get: { Double(difficulty) },
                            set: { difficulty = Int($0) }
                        ), in: 1...10, step: 1)
                        .tint(.indigo)
                        HStack {
                            Text("Easy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Max Effort")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Difficulty")
                }

                // Date
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .labelsHidden()
                }
            }
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSet() }
                        .disabled(selectedExercise == nil)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showExerciseSearch) {
                ExerciseSearchSheet(exercises: exercises) { exercise in
                    selectedExercise = exercise
                }
            }
            .onAppear {
                if let preselected = preselectedExercise {
                    selectedExercise = preselected
                    // Pre-fill with last logged values
                    if let lastSet = preselected.sets.sorted(by: { $0.date > $1.date }).first {
                        weight = lastSet.weight
                        weightText = lastSet.weight.formatted
                        reps = lastSet.reps
                    }
                }
            }
        }
    }

    private func saveSet() {
        guard let exercise = selectedExercise else { return }

        let existingSetsOnDate = exercise.sets.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        let setNumber = existingSetsOnDate.count + 1

        let workoutSet = WorkoutSet(
            date: date,
            setNumber: setNumber,
            reps: reps,
            weight: weight,
            difficulty: difficulty
        )
        workoutSet.exercise = exercise
        modelContext.insert(workoutSet)
        exercise.sets.append(workoutSet)

        dismiss()
    }
}

struct ExerciseSearchSheet: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showCreateSheet = false

    private var filtered: [Exercise] {
        searchText.isEmpty ? exercises : exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grouped: [(String, [Exercise])] {
        let dict = Dictionary(grouping: filtered) { $0.muscleGroup }
        return dict.map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    private var exactMatch: Bool {
        exercises.contains { $0.name.lowercased() == searchText.lowercased() }
    }

    var body: some View {
        NavigationStack {
            List {
                // "Create new" row when search has text and no exact match
                if !searchText.isEmpty && !exactMatch {
                    Section {
                        Button {
                            showCreateSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.indigo)
                                Text("Create \"\(searchText)\"")
                                    .foregroundStyle(.indigo)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                ForEach(grouped, id: \.0) { group, exList in
                    Section(group) {
                        ForEach(exList) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if exercise.maxWeight > 0 {
                                        Text("\(Int(exercise.maxWeight)) lbs max")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search or create exercise")
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        searchText = ""
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateExerciseSheet(initialName: searchText) { name, muscleGroup in
                    let exercise = Exercise(name: name, muscleGroup: muscleGroup)
                    modelContext.insert(exercise)
                    onSelect(exercise)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Create Exercise Sheet

struct CreateExerciseSheet: View {
    let initialName: String
    let onCreate: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var muscleGroup = "Arms"

    let muscleGroups = ["Arms", "Back", "Chest", "Legs", "Shoulders"]

    init(initialName: String, onCreate: @escaping (String, String) -> Void) {
        self.initialName = initialName
        self.onCreate = onCreate
        self._name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("e.g. Preacher Curls", text: $name)
                }
                Section("Muscle Group") {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(name.trimmingCharacters(in: .whitespaces), muscleGroup)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AddSetView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
}
