import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \WorkoutSet.date, order: .reverse) private var allSets: [WorkoutSet]
    @Query private var exercises: [Exercise]
    @Environment(AppTheme.self) private var theme
    @State private var showAddSet = false

    private var calendar: Calendar { Calendar.current }

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private var setsThisWeek: [WorkoutSet] {
        allSets.filter { $0.date >= weekStart }
    }

    private var volumeThisWeek: Double {
        setsThisWeek.reduce(0) { $0 + $1.volume }
    }

    private var workoutDaysThisWeek: Int {
        let days = Set(setsThisWeek.map { calendar.startOfDay(for: $0.date) })
        return days.count
    }

    private var recentSets: [WorkoutSet] {
        allSets
    }

    private var pinnedPRs: [(Exercise, Double)] {
        exercises
            .filter { $0.isFavorite }
            .compactMap { ex -> (Exercise, Double)? in
                let rm = ex.estimatedOneRM
                return (ex, rm > 0 ? rm : 0)
            }
            .sorted { $0.1 > $1.1 }
    }

    private var weeklyVolumeByDay: [(Date, Double)] {
        let grouped = Dictionary(grouping: setsThisWeek) { calendar.startOfDay(for: $0.date) }
        return grouped.map { (date, sets) in
            (date, sets.reduce(0) { $0 + $1.volume })
        }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Weekly stats header
                    weeklyStatsSection

                    // Weekly volume chart
                    if !weeklyVolumeByDay.isEmpty {
                        weeklyChartSection
                    }

                    // Pinned PRs
                    pinnedPRsSection

                    // Recent activity
                    if !recentSets.isEmpty {
                        recentActivitySection
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSet) {
                AddSetView()
            }
        }
    }

    // MARK: - Sections

    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                StatCard(
                    title: "Total Volume",
                    value: volumeThisWeek > 0 ? String(format: "%.0f lbs", volumeThisWeek) : "—",
                    icon: "scalemass.fill",
                    color: theme.accent
                )
                StatCard(
                    title: "Workout Days",
                    value: "\(workoutDaysThisWeek)",
                    icon: "calendar.badge.checkmark",
                    color: .purple
                )
                StatCard(
                    title: "Total Sets",
                    value: "\(setsThisWeek.count)",
                    icon: "repeat.circle.fill",
                    color: .blue
                )
            }
        }
    }

    private var weeklyChartSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Volume by Day")
                    .font(.headline)

                Chart(weeklyVolumeByDay, id: \.0) { day, volume in
                    BarMark(
                        x: .value("Day", day, unit: .day),
                        y: .value("Volume", volume)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.accent.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v / 1000))k")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }

    private var pinnedPRsSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("My PRs (Est. 1RM)")
                    .font(.headline)

                if pinnedPRs.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "star")
                            .foregroundStyle(.yellow)
                        Text("Swipe right on any exercise to pin it here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(pinnedPRs, id: \.0.persistentModelID) { exercise, rm in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(exercise.muscleGroup)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if rm > 0 {
                                Text(String(format: "%.0f lbs", rm))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(theme.accent)
                            } else {
                                Text("No data")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)

                        if exercise.persistentModelID != pinnedPRs.last?.0.persistentModelID {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Group by date
            let grouped = Dictionary(grouping: recentSets) { calendar.startOfDay(for: $0.date) }
            let sortedDates = grouped.keys.sorted(by: >).prefix(3)

            ForEach(Array(sortedDates), id: \.self) { day in
                let daySets = grouped[day] ?? []
                CardContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(day, style: .date)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Divider()
                        let exerciseGroups = Dictionary(grouping: daySets) { $0.exercise?.name ?? "Unknown" }
                        ForEach(Array(exerciseGroups.keys.sorted()), id: \.self) { exName in
                            let exSets = exerciseGroups[exName] ?? []
                            HStack {
                                Text(exName)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(exSets.count) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let maxW = exSets.map(\.weight).max() {
                                    Text("\(maxW.formatted) lbs max")
                                        .font(.caption)
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Exercise.self, WorkoutSet.self, WorkoutPlan.self, PlanExercise.self], inMemory: true)
        .environment(AppTheme())
}
