import SwiftUI
import AICatCore

/// Board of the Creative Lab: story seeds, remix, helper design and the graduation quiz.
struct CreativeBoard: View {
    let controller: CreativeLabController
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                switch controller.level {
                case .seeds:
                    if let challenge = controller.seedsChallenge { seedsView(challenge) }
                case .remix:
                    if let challenge = controller.remix { remixView(challenge) }
                case .helper:
                    if let challenge = controller.helper { helperView(challenge) }
                case .graduation:
                    if let challenge = controller.quiz { quizView(challenge) }
                }
                HStack(spacing: 12) {
                    Button(confirmTitle) { controller.confirm() }
                        .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                        .disabled(!controller.canConfirm)
                    if controller.level == .remix || controller.level == .helper {
                        hintButton
                    }
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }

    private var confirmTitle: String {
        switch controller.level {
        case .seeds, .remix: return L10n.string("story.remix_confirm")
        case .helper: return L10n.string("helper.done")
        case .graduation: return L10n.string("quiz.finish")
        }
    }

    @ViewBuilder
    private var hintButton: some View {
        Button {
            controller.requestHint()
        } label: {
            Label(app.profile.ageBand.autoHints ? L10n.string("common.hint") : L10n.format("sorting.hint_button", controller.hintsLeft), systemImage: "lightbulb.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .disabled(!controller.canRequestHint)
    }

    // MARK: Story seeds

    private func seedsView(_ challenge: StorySeedChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("story.pick_title")).font(.subheadline.bold())
            ForEach(StorySlot.allCases, id: \.self) { slot in
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("story.slot.\(slot.rawValue)")).font(.caption.bold()).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 150), spacing: 6)], spacing: 6) {
                        ForEach(StoryBank.words(for: slot)) { word in
                            Button {
                                controller.select(word)
                            } label: {
                                Text(L10n.string(word.key)).font(.callout).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(challenge.selection[slot] == word ? Theme.eyeGreen : Color.accentColor)
                            .disabled(controller.isDone)
                        }
                    }
                }
            }
            Button(L10n.string(challenge.stories.isEmpty ? "story.grow" : "story.grow_again")) { controller.grow() }
                .buttonStyle(KidButtonStyle(tint: Color.accentColor))
                .disabled(challenge.seeds == nil || controller.isDone || controller.isImagining)
            Text(L10n.format("story.progress_format", challenge.distinctSeedSets, challenge.required))
                .font(.caption)
                .foregroundStyle(.secondary)
            if controller.isImagining {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.string("story.thinking")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let story = challenge.latest {
                storyCard(story, sentences: controller.sentences(of: story), title: nil, onTap: nil)
            }
        }
    }

    private func storyCard(_ story: GeneratedStory, sentences: [String], title: String?, onTap: ((Int) -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).font(.title3.bold())
            }
            ForEach(Array(sentences.enumerated()), id: \.offset) { pair in
                if let onTap {
                    Button {
                        onTap(pair.offset)
                    } label: {
                        Text(pair.element)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Theme.eyeGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(pair.element).font(.body)
                }
            }
            Text(L10n.string(story.source == .model ? "story.source.model" : "story.source.patterns"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Remix

    private func remixView(_ challenge: RemixChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.format("story.remix_tip_format", challenge.requiredChanges)).font(.footnote).foregroundStyle(.secondary)
            storyCard(challenge.current,
                      sentences: controller.sentences(of: challenge.current),
                      title: challenge.titleIndex.map { L10n.string(StoryBank.titleKey($0)) },
                      onTap: { controller.cycle(sentence: $0) })
            Text(L10n.format("story.remix.changed_format", challenge.changedSentences, challenge.requiredChanges))
                .font(.caption)
                .foregroundStyle(challenge.changedSentences >= challenge.requiredChanges ? Theme.eyeGreen : Color.secondary)
            Text(L10n.string("story.title_prompt")).font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<StoryBank.titleCount, id: \.self) { index in
                    Button {
                        controller.chooseTitle(index)
                    } label: {
                        Text(L10n.string(StoryBank.titleKey(index))).font(.caption).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(challenge.titleIndex == index ? Theme.eyeGreen : Color.accentColor)
                    .disabled(controller.isDone)
                }
            }
            if challenge.isSolved {
                Text(L10n.string("story.remix_done")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
            }
        }
    }

    // MARK: Helper design

    private func helperView(_ challenge: HelperDesignChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            section(L10n.string("helper.goal_title")) {
                ForEach(HelperGoal.allCases, id: \.self) { goal in
                    choiceButton(L10n.string(goal.key), chosen: challenge.goal == goal) { controller.choose(goal) }
                }
            }
            section(L10n.string("helper.data_title")) {
                ForEach(HelperData.allCases, id: \.self) { item in
                    choiceButton(L10n.string(item.key), chosen: challenge.data.contains(item)) { controller.toggle(item) }
                }
            }
            section(L10n.string("helper.rules_title")) {
                ForEach(HelperRule.allCases, id: \.self) { rule in
                    choiceButton(L10n.string(rule.key), chosen: challenge.rules.contains(rule)) { controller.toggle(rule) }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("helper.checks_title")).font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(HelperCheck.allCases, id: \.self) { check in
                    HStack(spacing: 8) {
                        Image(systemName: challenge.passes(check) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(challenge.passes(check) ? Color.green : Color.secondary)
                        Text(L10n.string(check.key)).font(.callout)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 6)], spacing: 6) {
                content()
            }
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func choiceButton(_ title: String, chosen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(chosen ? Theme.eyeGreen : Color.accentColor)
        .disabled(controller.isDone)
    }

    // MARK: Graduation

    private func quizView(_ quiz: GraduationQuiz) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("quiz.title")).font(.subheadline.bold())
            Text(L10n.format("quiz.progress_format", quiz.answers.count, quiz.questions.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(quiz.questions) { question in
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string(question.key)).font(.callout.bold())
                    ForEach(0..<QuizQuestion.optionCount, id: \.self) { option in
                        let answered = quiz.answers[question.id] != nil
                        let chosen = quiz.answers[question.id] == option
                        Button {
                            controller.answer(question.id, option: option)
                        } label: {
                            HStack {
                                Text(L10n.string(question.optionKey(option))).font(.callout).multilineTextAlignment(.leading)
                                Spacer()
                                if answered && (chosen || option == question.answer) {
                                    Image(systemName: option == question.answer ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle(option == question.answer ? Color.green : Color.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(chosen ? Theme.eyeGreen : Color.accentColor)
                        .disabled(answered || controller.isDone)
                    }
                }
                .padding(12)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if quiz.isComplete {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🎓 " + L10n.string("quiz.diploma_title")).font(.title3.bold())
                    Text(L10n.format("quiz.diploma_text_format", controller.catName)).font(.callout)
                    Text(L10n.format("quiz.stats_format", app.profile.stage, app.profile.totalXP, app.profile.completedScenarioCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
