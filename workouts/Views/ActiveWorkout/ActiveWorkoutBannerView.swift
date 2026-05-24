//
//  ActiveWorkoutBannerView.swift
//  workouts
//
//  Created by Brady Chin on 2026.05.24.
//

import SwiftUI

struct ActiveWorkoutBannerView: View {
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
    ActiveWorkoutBannerView()
}
