import SwiftUI
import SwiftData

struct PlansView: View {
    @Query(sort: \WorkoutPlan.createdAt) private var plans: [WorkoutPlan]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreatePlan = false
    @State private var selectedPlan: WorkoutPlan?
    @State private var showActivePlan: WorkoutPlan?

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView {
                        Label("No Plans Yet", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Create a workout plan to get started")
                    } actions: {
                        Button("Create Plan") { showCreatePlan = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                    }
                } else {
                    List {
                        ForEach(plans) { plan in
                            PlanRowView(plan: plan) {
                                showActivePlan = plan
                            }
                        }
                        .onDelete(perform: deletePlans)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreatePlan = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .fullScreenCover(item: $showActivePlan) { plan in
                ActiveWorkoutView(plan: plan)
            }
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }
}

struct PlanRowView: View {
    let plan: WorkoutPlan
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                    Text("\(plan.planExercises.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Exercise chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(plan.sortedExercises) { planEx in
                        Text(planEx.exercise?.name ?? "Unknown")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    PlansView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
}
