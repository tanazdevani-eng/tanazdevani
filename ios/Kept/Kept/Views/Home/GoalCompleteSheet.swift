import SwiftUI

/// Shown once a fixed-duration habit's final day gets checked in — the "we'll ask if you
/// want to keep going" promise made on the duration picker (Add/Edit Habit) actually pays
/// off here instead of the habit just quietly running past its stated end date forever.
struct GoalCompleteSheet: View {
    @EnvironmentObject var appModel: AppModel
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GOAL REACHED")
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptOrangeDeep)
            Text("\u{201C}\(habit.name)\u{201D} wrapped up today.")
                .font(KeptFont.display(19, weight: .semibold))
                .foregroundStyle(.keptInk)
            Text("Keep it going with no end date, or let it end here. Either way, your streak and history stay yours.")
                .font(KeptFont.body(12.5, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .lineSpacing(2)
                .padding(.bottom, 14)

            Button("Keep going") { appModel.keepHabitGoing(habit) }
                .buttonStyle(.keptPrimary)

            Button("I'm done") { appModel.finishHabitGoal(habit) }
                .buttonStyle(KeptPillButtonStyle(background: .keptBackground, foreground: .keptInk, borderColor: .keptLine))
        }
        .padding(22)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}
