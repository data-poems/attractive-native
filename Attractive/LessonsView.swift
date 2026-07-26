import SwiftUI
import StoreKit

/// Browser for the guided curriculum. Tapping a lesson pushes its player. The
/// sheet uses medium/large detents so the live attractor stays visible behind
/// it while a lesson reconfigures the view.
struct LessonsHomeView: View {
    @Bindable var settings: AttractiveSettings
    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        settings.accentColor
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(LessonRegistry.all.enumerated()), id: \.element.id) { index, lesson in
                    NavigationLink {
                        LessonPlayerView(settings: settings, lesson: lesson)
                    } label: {
                        row(index: index, lesson: lesson)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(index: Int, lesson: Lesson) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 34, height: 34)
                if settings.isLessonComplete(lesson.id) {
                    Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(accent)
                } else {
                    Text("\(index + 1)").font(.subheadline.monospaced().weight(.semibold)).foregroundStyle(accent)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title).font(.body.weight(.medium)).foregroundStyle(.white)
                Text(lesson.subtitle).font(.caption).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.vertical, 4)
    }
}

/// Steps through a single lesson, applying each step's preset to the live view
/// and rendering its prose and any equations.
struct LessonPlayerView: View {
    @Bindable var settings: AttractiveSettings
    let lesson: Lesson
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    @State private var index = 0
    @State private var isShowingRecap = false

    private var step: LessonStep { lesson.steps[index] }
    private var isLast: Bool { index == lesson.steps.count - 1 }
    private var accent: Color {
        settings.accentColor
    }

    var body: some View {
        Group {
            if isShowingRecap {
                completionRecap
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    progressDots

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(step.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)

                            if !step.latex.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(step.latex.enumerated()), id: \.offset) { _, line in
                                        LaTeXLine(latex: line, color: .white, fontSize: 20)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            Text(step.body)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    controls
                }
            }
        }
        .padding(20)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { settings.apply(step.preset) }
        .onChange(of: index) { _, _ in settings.apply(step.preset) }
        .task(id: reviewOpportunityID) {
            await requestReviewAfterStableRecap()
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(lesson.steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? accent : Color.white.opacity(0.2))
                    .frame(width: i == index ? 22 : 7, height: 7)
            }
        }
    }

    private var controls: some View {
        HStack {
            if index > 0 {
                Button {
                    withAnimation { index -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left").font(.callout)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button {
                if isLast {
                    settings.markLessonComplete(lesson.id)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowingRecap = true
                    }
                } else {
                    withAnimation { index += 1 }
                }
            } label: {
                Text(isLast ? "Finish" : "Next")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(accent))
                    .foregroundStyle(.black)
            }
        }
    }

    private var completionRecap: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 58))
                .foregroundStyle(accent)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Lesson complete")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(lesson.title)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(settings.completedLessonCount) of \(LessonRegistry.all.count) lessons complete")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
            .multilineTextAlignment(.center)

            Text("Your progress is saved. The attractor stays on this lesson’s final setup, ready to rotate, tune, or compare.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button("Back to Lessons") { dismiss() }
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(accent))
                .foregroundStyle(.black)

            Button("Replay Lesson") {
                index = 0
                settings.apply(lesson.steps[0].preset)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowingRecap = false
                }
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson-completion-recap")
    }

    /// Changing either the recap or foreground state restarts the task. A
    /// return from the background therefore gets a fresh two-second stable
    /// window instead of attempting a request during scene activation.
    private var reviewOpportunityID: Int {
        (isShowingRecap ? 10 : 0) + (scenePhase == .active ? 1 : 0)
    }

    @MainActor
    private func requestReviewAfterStableRecap() async {
        guard isShowingRecap, scenePhase == .active else { return }
        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            return
        }
        guard !Task.isCancelled,
              isShowingRecap,
              scenePhase == .active,
              let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              settings.shouldRequestReview(currentVersion: version) else {
            return
        }

        requestReview()
        settings.markReviewRequested(currentVersion: version)
    }
}
