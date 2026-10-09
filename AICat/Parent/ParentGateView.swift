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

/// Parental gate: hold for two seconds, then answer a small sum.
struct ParentGateView: View {
    let onPass: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var holdDone = false
    @State private var a = 7
    @State private var b = 5
    @State private var options: [Int] = []
    @State private var wrong = false

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
                HStack(spacing: 12) {
                    ForEach(options, id: \.self) { value in
                        Button("\(value)") { check(value) }
                            .buttonStyle(KidButtonStyle())
                    }
                }
                if wrong {
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
    }

    private func newQuestion() {
        a = Int.random(in: 3...9)
        b = Int.random(in: 3...9)
        let correct = a + b
        var set: Set<Int> = [correct]
        while set.count < 3 {
            set.insert(max(1, correct + Int.random(in: -4...4)))
        }
        options = Array(set).shuffled()
    }

    private func check(_ value: Int) {
        if value == a + b {
            onPass()
        } else {
            wrong = true
            newQuestion()
        }
    }
}
