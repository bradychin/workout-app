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
                ActiveWorkoutBannerView()
                    .padding(.horizontal)
                    .padding(.bottom, 60) // sit above the tab bar
            }
        }
        .sheet(isPresented: $session.showWorkout) {
            ActiveWorkoutView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
        .environment(WorkoutSession())
}
