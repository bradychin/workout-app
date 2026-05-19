import SwiftData
import Foundation

struct DataSeeder {
    static let seededKey = "hasSeededData"

    // Block index → (name, muscleGroup)
    static let blockMapping: [Int: (String, String)] = [
        4: ("EZ-Bar Curls", "Arms"),
        5: ("Cable Lateral Raises", "Shoulders"),
        6: ("Cable Curls", "Arms"),
        7: ("Seated Cable Rows", "Back"),
        8: ("BtB Lateral Raises", "Shoulders"),
        9: ("Concentrated Curls", "Arms"),
        10: ("Back Extensions", "Back"),
        11: ("Split Squat", "Legs"),
        12: ("Rear Delt Flies", "Shoulders"),
        13: ("Egyptian Raises", "Shoulders"),
        14: ("Overhead Press (Dumbbell)", "Shoulders"),
        15: ("Rows (Barbell)", "Back"),
        16: ("Dips", "Chest"),
        17: ("Incline Bench Press (Dumbbell)", "Chest"),
        18: ("Calf Raises", "Legs"),
        19: ("Bulgarian Split Squats", "Legs"),
        20: ("Front Squat", "Legs"),
        21: ("Lateral, Front, Rear Raises", "Shoulders"),
        22: ("Shrugs", "Shoulders"),
        23: ("Seated Lateral Raises", "Shoulders"),
        24: ("Arnold Press", "Shoulders"),
        25: ("Hammer Curls", "Arms"),
        26: ("Bicep Curls", "Arms"),
        27: ("Rear Flies", "Back"),
        28: ("Deadlifts", "Back"),
        29: ("Rope Pulldowns", "Arms"),
        30: ("Skull Crushers", "Arms"),
        31: ("Chest Flies", "Chest"),
        32: ("Incline Bench Press (Barbell)", "Chest"),
        33: ("Bench Press (Barbell)", "Chest"),
        34: ("Back Squat", "Legs")
    ]

    // Exercises with no historical data
    static let extraExercises: [(String, String)] = [
        ("Pull Ups", "Back"),
        ("Bench Press (Dumbbell)", "Chest"),
        ("Leg Extensions", "Legs"),
        ("Overhead Press (Barbell)", "Shoulders"),
        ("Bent Over Row (Dumbbell)", "Back")
    ]

    // Workout plans definition
    static let plans: [(String, [(String, Int, String)])] = [
        ("Chest + Shoulders + Triceps", [
            ("Bench Press (Barbell)", 4, "5"),
            ("Incline Bench Press (Dumbbell)", 4, "8"),
            ("BtB Lateral Raises", 4, "15"),
            ("Skull Crushers", 3, "8")
        ]),
        ("Back + Biceps", [
            ("Deadlifts", 4, "5"),
            ("Rear Flies", 4, "15"),
            ("EZ-Bar Curls", 3, "8"),
            ("Bicep Curls", 4, "12")
        ]),
        ("Chest + Shoulders", [
            ("Incline Bench Press (Barbell)", 3, "8"),
            ("Dips", 3, "8"),
            ("Overhead Press (Dumbbell)", 3, "10"),
            ("Cable Lateral Raises", 5, "12"),
            ("Rope Pulldowns", 3, "12")
        ]),
        ("Back + Arms", [
            ("Pull Ups", 4, "-"),
            ("Rows (Barbell)", 4, "8"),
            ("Back Extensions", 3, "12"),
            ("Hammer Curls", 4, "12"),
            ("Cable Curls", 3, "12")
        ]),
        ("Legs", [
            ("Back Squat", 4, "5"),
            ("Split Squat", 3, "6"),
            ("Calf Raises", 4, "12")
        ])
    ]

    static func seedIfNeeded(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        let defaults = UserDefaults.standard

        // Build exercise name → Exercise map
        var exerciseMap: [String: Exercise] = [:]

        // Create exercises from block mapping
        var exercisesByName: [String: (String, String)] = [:]
        for (_, pair) in blockMapping {
            exercisesByName[pair.0] = pair
        }
        for pair in extraExercises {
            exercisesByName[pair.0] = pair
        }

        for (name, (_, group)) in exercisesByName {
            let exercise = Exercise(name: name, muscleGroup: group)
            context.insert(exercise)
            exerciseMap[name] = exercise
        }

        // Parse CSV
        parseCsvData(into: exerciseMap, context: context)

        // Create plans
        for (planName, exercises) in plans {
            let plan = WorkoutPlan(name: planName)
            context.insert(plan)
            for (index, (exerciseName, sets, reps)) in exercises.enumerated() {
                let planEx = PlanExercise(targetSets: sets, targetReps: reps, order: index)
                planEx.plan = plan
                planEx.exercise = exerciseMap[exerciseName]
                context.insert(planEx)
                plan.planExercises.append(planEx)
            }
        }

        do {
            try context.save()
            defaults.set(true, forKey: seededKey)
        } catch {
            print("DataSeeder save error: \(error)")
        }
    }

    private static func parseCsvData(into exerciseMap: [String: Exercise], context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "workout-data", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("DataSeeder: Could not load workout-data.csv")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        let lines = content.components(separatedBy: "\n")
        var blockIndex = 0
        var currentBlockIndex = 0
        var i = 0

        while i < lines.count {
            let line = lines[i]
            // Detect block header
            if line.hasPrefix(",,Date,Set,Reps,Weight") {
                blockIndex += 1
                currentBlockIndex = blockIndex
                i += 1
                continue
            }

            // Skip if not in a known block
            guard let (exerciseName, _) = blockMapping[currentBlockIndex],
                  let exercise = exerciseMap[exerciseName] else {
                i += 1
                continue
            }

            let cols = parseCSVLine(line)
            guard cols.count >= 7 else {
                i += 1
                continue
            }

            let dateStr = cols[2].trimmingCharacters(in: .whitespaces)
            let setStr = cols[3].trimmingCharacters(in: .whitespaces)
            let repsStr = cols[4].trimmingCharacters(in: .whitespaces)
            let weightStr = cols[5].trimmingCharacters(in: .whitespaces)
            let diffStr = cols[6].trimmingCharacters(in: .whitespaces)

            // Skip monthly summary rows (no date, no set number that's a simple integer)
            guard let date = dateFormatter.date(from: dateStr),
                  let setNum = Int(setStr),
                  let reps = Int(repsStr),
                  let weight = Double(weightStr),
                  let diff = Int(diffStr),
                  weight > 0 else {
                i += 1
                continue
            }

            let workoutSet = WorkoutSet(
                date: date,
                setNumber: setNum,
                reps: reps,
                weight: weight,
                difficulty: diff
            )
            workoutSet.exercise = exercise
            context.insert(workoutSet)
            exercise.sets.append(workoutSet)

            i += 1
        }
    }

    /// Parse a single CSV line respecting quoted fields
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
}
