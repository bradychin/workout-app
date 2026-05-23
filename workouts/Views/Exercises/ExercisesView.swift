import SwiftUI
import SwiftData

struct ExercisesView: View {
    @Query(sort: \Exercise.muscleGroup) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showAddSet = false
    @State private var selectedExerciseForSet: Exercise?

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.muscleGroup.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grouped: [(String, [Exercise])] {
        let dict = Dictionary(grouping: filteredExercises) { $0.muscleGroup }
        return dict.map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Data will appear after seeding")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.0) { group, exList in
                            Section {
                                ForEach(exList) { exercise in
                                    NavigationLink {
                                        ExerciseDetailView(exercise: exercise)
                                    } label: {
                                        ExerciseRowView(exercise: exercise)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            exercise.isFavorite.toggle()
                                        } label: {
                                            Label(
                                                exercise.isFavorite ? "Unpin" : "Pin to Dashboard",
                                                systemImage: exercise.isFavorite ? "star.slash.fill" : "star.fill"
                                            )
                                        }
                                        .tint(.yellow)
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: muscleGroupIcon(group))
                                        .foregroundStyle(.indigo)
                                    Text(group)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showAddSet) {
                AddSetView()
            }
        }
    }

    private func muscleGroupIcon(_ group: String) -> String {
        switch group {
        case "Arms": return "figure.arms.open"
        case "Back": return "figure.strengthtraining.traditional"
        case "Chest": return "figure.cooldown"
        case "Legs": return "figure.run"
        case "Shoulders": return "figure.boxing"
        default: return "dumbbell.fill"
        }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.body)
                    .fontWeight(.medium)

                if exercise.sets.isEmpty {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(exercise.sets.count) sets logged")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if exercise.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            if exercise.maxWeight > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(exercise.maxWeight.lbs)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                    Text("max")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ExercisesView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
}
