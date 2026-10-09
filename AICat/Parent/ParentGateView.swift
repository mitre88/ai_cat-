import SwiftUI

/// Sheet flow: gate first, then the parent zone.
struct ParentFlowView: View {
    @State private var passed = false

    var body: some View {
        NavigationStack {
            if passed {
                ParentZoneView()
            } else {
                ParentGateView { passed = true }
            }
        }
    }
}

/// Parental gate: hold the paw for two seconds, then type the answer to a two-digit sum.
/// A wrong answer locks the gate for a few seconds and changes the question, so guessing does not pay.
struct ParentGateView: View {
    let onPass: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var holdDone = false
    @State private var a = 23
    @State private var b = 48
    @State private var answer = ""
    @State private var wrong = false
    @State private var lockedUntil: Date?
    @State private var secondsLeft = 0

    static let lockSeconds = 5

    private var isLocked: Bool { lockedUntil.map { $0 > Date() } ?? false }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.eyeGreen)
            Text(L10n.string("parent.gate_title"))
                .font(.title.bold())
            if holdDone {
                Text(L10n.format("parent.gate_question", a, b))
                    .font(.title2)
                TextField(L10n.string("parent.gate_answer"), text: $answer)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .frame(maxWidth: 180)
                    .disabled(isLocked)
                Button(L10n.string("parent.gate_check")) { check() }
                    .buttonStyle(KidButtonStyle())
                    .disabled(isLocked || answer.trimmingCharacters(in: .whitespaces).isEmpty)
                if isLocked {
                    Text(L10n.format("parent.gate_wait_format", secondsLeft))
                        .foregroundStyle(.red)
                } else if wrong {
                    Text(L10n.string("parent.gate_wrong"))
                        .foregroundStyle(.red)
                }
            } else {
                Text(L10n.string("parent.gate_hold"))
                    .multilineTextAlignment(.center)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 44))
                    .padding(30)
                    .background(Circle().fill(Theme.eyeGreen.opacity(0.2)))
                    .onLongPressGesture(minimumDuration: 2.0) {
                        holdDone = true
                        newQuestion()
                    }
            }
            Button(L10n.string("common.cancel")) { dismiss() }
                .padding(.top)
        }
        .padding(32)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.mapBackground.ignoresSafeArea())
        .task(id: lockedUntil) { await countDown() }
    }

    private func newQuestion() {
        a = Int.random(in: 12...49)
        b = Int.random(in: 11...49)
        answer = ""
    }

    private func check() {
        guard !isLocked else { return }
        if Int(answer.trimmingCharacters(in: .whitespaces)) == a + b {
            onPass()
        } else {
            wrong = true
            lockedUntil = Date().addingTimeInterval(TimeInterval(Self.lockSeconds))
            newQuestion()
        }
    }

    /// Ticks the lockout once per second until it ends.
    private func countDown() async {
        guard let lockedUntil else { return }
        while !Task.isCancelled {
            let left = Int(lockedUntil.timeIntervalSinceNow.rounded(.up))
            secondsLeft = max(0, left)
            if left <= 0 {
                self.lockedUntil = nil
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
