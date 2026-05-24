//
//  HistoryCardView.swift
//  workouts
//
//  Created by Brady Chin on 2026.05.24.
//

import SwiftUI

struct HistoryCardView: View {
    let date: Date
    let sets: [WorkoutSet]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                let sessionVolume = sets.reduce(0.0) { $0 + $1.volume }
                Text(String(format: "%.0f lbs vol", sessionVolume))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(spacing: 6) {
                ForEach(sets) { set in
                    HStack {
                        Text("Set \(set.setNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)

                        Text(set.weight.lbs)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("×")
                            .foregroundStyle(.secondary)

                        Text("\(set.reps) reps")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        DifficultyBadge(difficulty: set.difficulty)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let sets: [WorkoutSet] = [
        WorkoutSet(date: .now, setNumber: 1, reps: 8, weight: 185, difficulty: 7),
        WorkoutSet(date: .now, setNumber: 2, reps: 8, weight: 185, difficulty: 8),
        WorkoutSet(date: .now, setNumber: 3, reps: 6, weight: 195, difficulty: 9)
    ]
    HistoryCardView(date: .now, sets: sets)
        .padding()
}
