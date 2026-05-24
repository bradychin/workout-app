import SwiftUI

struct SetWeightView: View {
    @Binding var weight: Double

    var fontSize: CGFloat = 48
    var cardWidth: CGFloat? = nil       // nil = size to content
    var verticalPadding: CGFloat = 10
    var horizontalPadding: CGFloat = 16

    @Environment(AppTheme.self) private var theme
    @State private var weightText: String = ""
    @FocusState private var focused: Bool

    init(
        weight: Binding<Double>,
        fontSize: CGFloat = 48,
        cardWidth: CGFloat? = nil,
        verticalPadding: CGFloat = 10,
        horizontalPadding: CGFloat = 16
    ) {
        self._weight = weight
        self.fontSize = fontSize
        self.cardWidth = cardWidth
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self._weightText = State(initialValue: weight.wrappedValue.formatted)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(focused ? theme.accent : .primary)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                commitText()
                                focused = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .onChange(of: weightText) { _, newVal in
                        if let val = Double(newVal), val >= 0 {
                            weight = val
                        }
                    }
                    .onChange(of: weight) { _, newVal in
                        let formatted = newVal.formatted
                        if weightText != formatted {
                            weightText = formatted
                        }
                    }

                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(focused ? theme.accent : .secondary)
                    .padding(.top, fontSize * 0.1)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(focused ? theme.accent.opacity(0.08) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(focused ? theme.accent : Color.clear, lineWidth: 1.5)
            )
            .onTapGesture { focused = true }

            if !focused {
                Text("Tap to edit")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func commitText() {
        if let val = Double(weightText), val >= 0 {
            weight = val
            weightText = val.formatted
        } else {
            weightText = weight.formatted
        }
    }
}

#Preview {
    @Previewable @State var weight: Double = 135

    VStack(spacing: 32) {
        Text("Default").foregroundStyle(.secondary)
        SetWeightView(weight: $weight)

        Text("Compact (form)").foregroundStyle(.secondary)
        SetWeightView(weight: $weight, fontSize: 34, cardWidth: 160, verticalPadding: 8)

        Text("Large (full-screen)").foregroundStyle(.secondary)
        SetWeightView(weight: $weight, fontSize: 56, cardWidth: 200, verticalPadding: 14)

        Text("Current: \(weight.formatted) lbs")
            .foregroundStyle(.secondary)
    }
    .padding()
    .environment(AppTheme())
}
