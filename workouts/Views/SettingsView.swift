import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \WorkoutSet.date) private var allSets: [WorkoutSet]
    @Query private var allExercises: [Exercise]

    @State private var exportItem: CSVExportItem?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    exportRow
                } header: {
                    Text("Data")
                } footer: {
                    Text("Exports all logged sets as a CSV file. You can open it in Excel, Numbers, or Google Sheets.")
                }

                Section("About") {
                    LabeledContent("Total Exercises", value: "\(allExercises.count)")
                    LabeledContent("Total Sets Logged", value: "\(allSets.count)")
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $exportItem) { item in
                ShareSheet(url: item.url)
                    .ignoresSafeArea()
            }
            .alert("Export Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "Unknown error")
            }
        }
    }

    private var exportRow: some View {
        Button {
            generateExport()
        } label: {
            HStack {
                Label("Export to CSV", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.indigo)
                Spacer()
                if isExporting {
                    ProgressView()
                }
            }
        }
        .disabled(isExporting || allSets.isEmpty)
    }

    private func generateExport() {
        isExporting = true
        let sets = allSets
        Task.detached {
            do {
                let url = try buildCSV(from: sets)
                await MainActor.run {
                    isExporting = false
                    exportItem = CSVExportItem(url: url)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    nonisolated private func buildCSV(from sets: [WorkoutSet]) throws -> URL {
        var rows: [String] = [
            "Exercise,Muscle Group,Date,Set,Reps,Weight (lbs),Difficulty,Volume (lbs),Est 1RM (lbs)"
        ]

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        let sorted = sets.sorted {
            let nameA = $0.exercise?.name ?? ""
            let nameB = $1.exercise?.name ?? ""
            if nameA != nameB { return nameA < nameB }
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.setNumber < $1.setNumber
        }

        for set in sorted {
            let name = csvEscape(set.exercise?.name ?? "Unknown")
            let group = csvEscape(set.exercise?.muscleGroup ?? "Unknown")
            let date = csvEscape(formatter.string(from: set.date))
            let volume = set.weight * Double(set.reps)
            let oneRM = set.weight > 0 && set.reps > 0
                ? set.weight * (1 + Double(set.reps) / 30.0)
                : 0.0

            rows.append("\(name),\(group),\(date),\(set.setNumber),\(set.reps),\(set.weight),\(set.difficulty),\(String(format: "%.1f", volume)),\(String(format: "%.1f", oneRM))")
        }

        let content = rows.joined(separator: "\n")
        let filename = "workouts-\(exportDateStamp()).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    nonisolated private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    nonisolated private func exportDateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// Identifiable wrapper so .sheet(item:) works
struct CSVExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

// UIActivityViewController wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
}
