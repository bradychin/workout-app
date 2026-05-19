import SwiftUI
import SwiftData

struct PlanDetailView: View {
    let plan: WorkoutPlan
    @Environment(WorkoutSession.self) private var workoutSession
    @State private var showEditPlan = false

    var body: some View {
        @Bindable var session = workoutSession

        List {
            Section {
                ForEach(plan.sortedExercises) { planEx in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(planEx.exercise?.name ?? "Unknown")
                                .font(.body)
                                .fontWeight(.medium)
                            Text(planEx.targetDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let exercise = planEx.exercise, exercise.maxWeight > 0 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.0f lbs", exercise.maxWeight))
                                    .font(.caption)
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
            } header: {
                Text("\(plan.sortedExercises.count) Exercises")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEditPlan = true }
                    .foregroundStyle(.indigo)
            }
        }
        .safeAreaInset(edge: .bottom) {
            startButton
        }
        .sheet(isPresented: $showEditPlan) {
            CreatePlanView(editingPlan: plan)
        }
    }

    private var startButton: some View {
        Button {
            workoutSession.start(plan: plan)
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(workoutSession.isActive ? Color(.systemFill) : Color.indigo)
                .foregroundStyle(workoutSession.isActive ? Color.secondary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(workoutSession.isActive)
        .overlay(alignment: .bottom) {
            if workoutSession.isActive {
                Text("A workout is already in progress")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .offset(y: 18)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(Color(.systemBackground).opacity(0.95))
    }
}

#Preview {
    NavigationStack {
        PlanDetailView(plan: WorkoutPlan(name: "Push Day"))
    }
    .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
    .environment(WorkoutSession())
}
