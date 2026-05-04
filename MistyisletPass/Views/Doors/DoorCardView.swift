import SwiftUI

struct DoorCardView: View {
    let door: Door
    let isBLEReady: Bool
    let onHoldStart: () -> Void
    let onHoldProgress: (Double) -> Void
    let onHoldComplete: () -> Void
    let onHoldCancel: () -> Void

    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer?
    @GestureState private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Status + Door Name
            HStack(spacing: 8) {
                statusIndicator
                Text(door.name)
                    .font(.headline)
                Spacer()
                if isBLEReady {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.brandPrimary)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
            }

            // Building + Floor
            Text("\(door.building) \u{00B7} \(door.floor)")
                .font(.body)
                .foregroundStyle(.secondary)

            // Action area
            if door.canUnlock {
                holdToUnlockButton
            } else {
                Text(door.statusDescription)
                    .font(.callout)
                    .foregroundStyle(door.controllerOnline ? .secondary : .orange)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(door.name), \(door.floor), \(door.building), \(door.statusDescription)")
        .accessibilityHint(door.canUnlock ? "Long press to unlock" : "")
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    private var statusColor: Color {
        if !door.controllerOnline {
            return .red
        } else if !door.gatewayOnline {
            return .orange
        }
        return .green
    }

    private var holdToUnlockButton: some View {
        ZStack(alignment: .leading) {
            // Progress fill
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.brandPrimary.opacity(0.3))
                    .frame(width: geo.size.width * holdProgress, height: 44)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Label
            HStack {
                Image(systemName: holdProgress >= 1.0 ? "lock.open.fill" : "lock.fill")
                Text(holdProgress >= 1.0 ? "Release to Unlock" : "Hold to Unlock")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(holdProgress > 0 ? .brandPrimary : .primary)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        .gesture(
            LongPressGesture(minimumDuration: 0.01)
                .onChanged { _ in
                    startHold()
                }
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onEnded { _ in
                    endHold()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if isHolding {
                        endHold()
                    }
                }
        )
        .accessibilityAction {
            onHoldStart()
            onHoldComplete()
        }
        .onDisappear {
            holdTimer?.invalidate()
            holdTimer = nil
        }
    }

    private func startHold() {
        guard !isHolding else { return }
        isHolding = true
        holdProgress = 0
        onHoldStart()

        // Animate progress over holdDuration
        let interval: TimeInterval = 0.02
        let steps = Constants.UI.unlockHoldDuration / interval
        var currentStep = 0.0

        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = currentStep / steps
            holdProgress = min(progress, 1.0)
            onHoldProgress(holdProgress)

            if progress >= 1.0 {
                timer.invalidate()
            }
        }
    }

    private func endHold() {
        holdTimer?.invalidate()
        holdTimer = nil

        if holdProgress >= 1.0 {
            onHoldComplete()
        } else {
            onHoldCancel()
        }

        withAnimation(.easeOut(duration: 0.2)) {
            holdProgress = 0
        }
        isHolding = false
    }
}

#Preview {
    DoorCardView(
        door: Door(
            id: "1",
            name: "Main Entrance",
            building: "Lobby",
            floor: "Floor 1",
            gatewayOnline: true,
            controllerOnline: true,
            hasPermission: true
        ),
        isBLEReady: true,
        onHoldStart: {},
        onHoldProgress: { _ in },
        onHoldComplete: {},
        onHoldCancel: {}
    )
    .padding()
}
