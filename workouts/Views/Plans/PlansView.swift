import SwiftUI
import SwiftData

struct PlansView: View {
    @Query(sort: \WorkoutPlan.createdAt) private var plans: [WorkoutPlan]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppTheme.self) private var theme
    @State private var showCreatePlan = false

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
                            .tint(theme.accent)
                    }
                } else {
                    List {
                        ForEach(plans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                PlanRowView(plan: plan)
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
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name)
                .font(.headline)
            Text("\(plan.sortedExercises.count) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)

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
        .padding(.vertical, 4)
    }
}

#Preview {
    PlansView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
        .environment(WorkoutSession())
        .environment(AppTheme())
}
