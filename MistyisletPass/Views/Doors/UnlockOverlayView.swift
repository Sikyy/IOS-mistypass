import SwiftUI

struct UnlockOverlayView: View {
    let state: UnlockState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Translucent background
            overlayBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                switch state {
                case .idle, .holding:
                    EmptyView()

                case .connecting:
                    connectingContent

                case .granted(let doorName):
                    grantedContent(doorName: doorName)

                case .denied(let doorName, let reason):
                    deniedContent(doorName: doorName, reason: reason)

                case .failed(let doorName, let reason):
                    deniedContent(doorName: doorName, reason: reason)
                }
            }
            .padding(40)
        }
    }

    private var overlayBackground: some View {
        Group {
            switch state {
            case .granted:
                Color.green.opacity(0.15)
            case .denied, .failed:
                Color.red.opacity(0.15)
            default:
                Color.clear
            }
        }
        .glassEffect(.regular, in: .rect)
    }

    private var connectingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.brandPrimary)
                .symbolEffect(
                    reduceMotion ? .pulse : .variableColor.iterative,
                    options: .repeating
                )

            Text("Connecting...")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .accessibilityLabel("Connecting to door controller")
    }

    private func grantedContent(doorName: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(reduceMotion ? .pulse : .bounce, options: .nonRepeating)

            Text("Door Unlocked")
                .font(.title2)
                .fontWeight(.semibold)

            Text(doorName)
                .font(.body)
                .foregroundStyle(.secondary)

            Text(Date(), style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Access granted for \(doorName)")
    }

    private func deniedContent(doorName: String, reason: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Access Denied")
                .font(.title2)
                .fontWeight(.semibold)

            Text(reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityLabel("Access denied for \(doorName): \(reason)")
    }
}

#Preview("Connecting") {
    UnlockOverlayView(state: .connecting)
}

#Preview("Granted") {
    UnlockOverlayView(state: .granted(doorName: "Main Entrance"))
}

#Preview("Denied") {
    UnlockOverlayView(state: .denied(doorName: "Server Room", reason: "No permission for this door"))
}
