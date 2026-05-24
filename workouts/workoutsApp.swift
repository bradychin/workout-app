import SwiftUI
import SwiftData

@main
struct workoutsApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    @State private var workoutSession = WorkoutSession()
    @State private var appTheme = AppTheme()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(workoutSession)
                .environment(appTheme)
        }
    }
}
