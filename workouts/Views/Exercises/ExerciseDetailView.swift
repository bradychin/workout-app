import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(AppTheme.self) private var theme
    @State private var selectedMonth: Date? = nil
    @State private var showAddSet = false
    @State private var selectedChart: ChartType = .maxWeight
    @State private var showRename = false
    @State private var pendingName = ""

    enum ChartType: String, CaseIterable {
        case maxWeight = "Max Weight"
        case volume = "Volume"
        case oneRM = "Est. 1RM"
    }

    private var calendar: Calendar { Calendar.current }

    private var availableMonths: [Date] {
        let months = Set(exercise.sets.map {
            calendar.dateInterval(of: .month, for: $0.date)!.start
        })
        return months.sorted(by: >)
    }

    private var filteredSets: [WorkoutSet] {
        guard let month = selectedMonth else { return exercise.sets }
        let interval = calendar.dateInterval(of: .month, for: month)!
        return exercise.sets.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    private struct SessionData: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
        let totalVolume: Double
        let maxOneRM: Double
    }

    private var sessionData: [SessionData] {
        let grouped = Dictionary(grouping: filteredSets) { calendar.startOfDay(for: $0.date) }
        return grouped.map { date, sets in
            SessionData(
                date: date,
                maxWeight: sets.map(\.weight).max() ?? 0,
                totalVolume: sets.reduce(0) { $0 + $1.volume },
                maxOneRM: sets.map(\.estimatedOneRM).max() ?? 0
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var sortedSets: [WorkoutSet] {
        filteredSets.sorted { $0.date > $1.date }
    }

    private var maxWeightEver: Double { exercise.sets.map(\.weight).max() ?? 0 }
    private var bestOneRM: Double { exercise.estimatedOneRM }
    private var totalVolume: Double { exercise.totalVolume }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsRow
                if !availableMonths.isEmpty { monthFilterRow }
                chartPickerSection
                historySection
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        pendingName = exercise.name
                        showRename = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(theme.accent)
                    }
                    Button {
                        showAddSet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSet) {
            AddSetView(preselectedExercise: exercise)
        }
        .alert("Rename Exercise", isPresented: $showRename) {
            TextField("Exercise name", text: $pendingName)
            Button("Save") {
                let trimmed = pendingName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { exercise.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for \"\(exercise.name)\"")
        }
    }

    // MARK: - Sections

    private var statsRow: some View {
        HStack(spacing: 12) {
            MiniStatCard(title: "Max Weight", value: maxWeightEver > 0 ? maxWeightEver.lbs : "—", color: theme.accent)
            MiniStatCard(title: "Est. 1RM", value: bestOneRM > 0 ? "\(Int(bestOneRM)) lbs" : "—", color: theme.accent.opacity(0.7))
            MiniStatCard(title: "Total Sets", value: "\(exercise.sets.count)", color: .secondary)
        }
    }

    private var monthFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MonthChip(title: "All", isSelected: selectedMonth == nil, accent: theme.accent) {
                    withAnimation { selectedMonth = nil }
                }
                ForEach(availableMonths, id: \.self) { month in
                    MonthChip(
                        title: month.formatted(.dateTime.month(.abbreviated).year()),
                        isSelected: selectedMonth == month,
                        accent: theme.accent
                    ) {
                        withAnimation { selectedMonth = month }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var chartPickerSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Chart", selection: $selectedChart) {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if sessionData.isEmpty {
                    Text("No data for selected period")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 160)
                } else {
                    chartContent
                        .frame(height: 180)
                }
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        Chart(sessionData) { session in
            switch selectedChart {

            case .maxWeight:
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("Max Weight", session.maxWeight)
                )
                .foregroundStyle(theme.accent)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", session.date),
                    y: .value("Max Weight", session.maxWeight)
                )
                .foregroundStyle(
                    LinearGradient(colors: [theme.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", session.date),
                    y: .value("Max Weight", session.maxWeight)
                )
                .foregroundStyle(theme.accent)
                .symbolSize(30)

            case .volume:
                BarMark(
                    x: .value("Date", session.date, unit: .day),
                    y: .value("Volume", session.totalVolume)
                )
                .foregroundStyle(
                    LinearGradient(colors: [theme.accent, theme.accent.opacity(0.6)], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)

            case .oneRM:
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("Est. 1RM", session.maxOneRM)
                )
                .foregroundStyle(theme.accent)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", session.date),
                    y: .value("Est. 1RM", session.maxOneRM)
                )
                .foregroundStyle(
                    LinearGradient(colors: [theme.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", session.date),
                    y: .value("Est. 1RM", session.maxOneRM)
                )
                .foregroundStyle(theme.accent)
                .symbolSize(30)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel().font(.caption2)
                AxisGridLine()
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)

            if sortedSets.isEmpty {
                CardContainer {
                    Text("No sets logged yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } else {
                let grouped = Dictionary(grouping: sortedSets) { calendar.startOfDay(for: $0.date) }
                let sortedDays = grouped.keys.sorted(by: >)

                ForEach(sortedDays, id: \.self) { day in
                    let daySets = (grouped[day] ?? []).sorted { $0.setNumber < $1.setNumber }
                    HistoryCardView(date: day, sets: daySets)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MonthChip: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? accent : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: {
            let e = Exercise(name: "Bench Press (Barbell)", muscleGroup: "Chest")
            return e
        }())
    }
    .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
    .environment(AppTheme())
}
