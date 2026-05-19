import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSession.self) private var workoutSession
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var session = workoutSession

        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                    .tag(0)

                ExercisesView()
                    .tabItem { Label("Exercises", systemImage: "dumbbell.fill") }
                    .tag(1)

                PlansView()
                    .tabItem { Label("Plans", systemImage: "list.bullet.clipboard.fill") }
                    .tag(2)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(3)
            }
            .tint(.indigo)
            .task {
                DataSeeder.seedIfNeeded(modelContext)
            }

            // Floating active workout banner — visible from any tab
            if workoutSession.isActive {
                ActiveWorkoutBanner()
                    .padding(.horizontal)
                    .padding(.bottom, 60) // sit above the tab bar
            }
        }
        .sheet(isPresented: $session.showWorkout) {
            ActiveWorkoutView()
        }
    }
}

// MARK: - Floating banner

struct ActiveWorkoutBanner: View {
    @Environment(WorkoutSession.self) private var workoutSession

    var body: some View {
        @Bindable var session = workoutSession

        Button {
            session.showWorkout = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutSession.activePlan?.name ?? "Workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(workoutSession.startTime, style: .timer)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .monospacedDigit()
                }

                Spacer()

                Text("\(workoutSession.totalSetsLogged) sets")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))

                Image(systemName: "chevron.up")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.indigo)
                    .shadow(color: .indigo.opacity(0.4), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
        .environment(WorkoutSession())
}
