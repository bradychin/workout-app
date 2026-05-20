import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise

    @State private var selectedMonth: Date? = nil
    @State private var showAddSet = false
    @State private var selectedChart: ChartType = .oneRM

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

    // Group sets by session date, compute per-session stats
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

    // Stats
    private var maxWeightEver: Double {
        exercise.sets.map(\.weight).max() ?? 0
    }
    private var bestOneRM: Double {
        exercise.estimatedOneRM
    }
    private var totalVolume: Double {
        exercise.totalVolume
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats row
                statsRow

                // Month filter
                if !availableMonths.isEmpty {
                    monthFilterRow
                }

                // Chart picker
                chartPickerSection

                // History
                historySection
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
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
            AddSetView(preselectedExercise: exercise)
        }
    }

    // MARK: - Sections

    private var statsRow: some View {
        HStack(spacing: 12) {
            MiniStatCard(title: "Max Weight", value: maxWeightEver > 0 ? "\(Int(maxWeightEver)) lbs" : "—", color: .indigo)
            MiniStatCard(title: "Est. 1RM", value: bestOneRM > 0 ? "\(Int(bestOneRM)) lbs" : "—", color: .purple)
            MiniStatCard(title: "Total Sets", value: "\(exercise.sets.count)", color: .blue)
        }
    }

    private var monthFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MonthChip(title: "All", isSelected: selectedMonth == nil) {
                    withAnimation { selectedMonth = nil }
                }
                ForEach(availableMonths, id: \.self) { month in
                    MonthChip(
                        title: month.formatted(.dateTime.month(.abbreviated).year()),
                        isSelected: selectedMonth == month
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
                .foregroundStyle(.purple)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", session.date),
                    y: .value("Max Weight", session.maxWeight)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.purple.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", session.date),
                    y: .value("Max Weight", session.maxWeight)
                )
                .foregroundStyle(.purple)
                .symbolSize(30)
                
            case .volume:
                BarMark(
                    x: .value("Date", session.date, unit: .day),
                    y: .value("Volume", session.totalVolume)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(4)

            
                
            case .oneRM:
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("Est. 1RM", session.maxOneRM)
                )
                .foregroundStyle(.indigo)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", session.date),
                    y: .value("Est. 1RM", session.maxOneRM)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.indigo.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", session.date),
                    y: .value("Est. 1RM", session.maxOneRM)
                )
                .foregroundStyle(.indigo)
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
                AxisValueLabel()
                    .font(.caption2)
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
                // Group by day
                let grouped = Dictionary(grouping: sortedSets) { calendar.startOfDay(for: $0.date) }
                let sortedDays = grouped.keys.sorted(by: >)

                ForEach(sortedDays, id: \.self) { day in
                    let daySets = (grouped[day] ?? []).sorted { $0.setNumber < $1.setNumber }
                    CardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(day, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(daySets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            VStack(spacing: 6) {
                                ForEach(daySets) { set in
                                    SetHistoryRow(set: set)
                                }
                            }
                        }
                    }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.indigo : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SetHistoryRow: View {
    let set: WorkoutSet

    var difficultyColor: Color {
        switch set.difficulty {
        case 1...4: return .green
        case 5...7: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(set.setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text("\(Int(set.weight)) lbs")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("×")
                .foregroundStyle(.secondary)

            Text("\(set.reps) reps")
                .font(.subheadline)

            Spacer()

            // Difficulty indicator
            HStack(spacing: 2) {
                ForEach(1...10, id: \.self) { i in
                    Circle()
                        .fill(i <= set.difficulty ? difficultyColor : Color(.systemFill))
                        .frame(width: 5, height: 5)
                }
            }
        }
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
}
