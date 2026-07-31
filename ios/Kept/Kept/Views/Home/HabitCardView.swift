import SwiftUI

struct HabitCardView: View {
    @EnvironmentObject var appModel: AppModel
    let habit: Habit
    var onCheckInTapped: () -> Void
    var onEditTapped: () -> Void
    var onPhotosTapped: () -> Void

    private var calendar: DayCalendar { appModel.dayCalendar }
    private var checkedInToday: Bool { habit.isCheckedIn(calendar: calendar) }
    private var isDownDayToday: Bool { appModel.downDayHabitIds.contains(habit.id) }
    private var streak: Int { habit.streakCount(calendar: calendar) }
    private var hasActiveGoal: Bool { habit.goalDurationDays != nil }

    /// Both keptChip and keptSurface were tried here for the down-day state and both read
    /// as an off/washed-out white next to the solid black default and green success fills —
    /// keptMuted is a real amber/gold now, an actual third color in the same language as
    /// green "Checked in," not another near-neutral.
    private var checkInButtonBackground: Color {
        if checkedInToday { return .keptSuccess }
        if isDownDayToday { return .keptMuted }
        return .keptInkFill
    }

    private var checkInButtonForeground: Color {
        isDownDayToday && !checkedInToday ? .keptInk : .white
    }

    var body: some View {
        KeptCard(fill: AnyShapeStyle(habit.visibility.cardGradient), borderColor: habit.visibility.borderColor, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 0) {
                topRow

                streakRow.padding(.top, 12)

                Divider().overlay(Color.keptInk.opacity(0.08)).padding(.top, 12)

                checkInButton
                    .padding(.top, 10)
            }
            .padding(EdgeInsets(top: 15, leading: 16, bottom: 14, trailing: 16))
        }
    }

    /// The small dots-row-plus-count is the one display every card gets, goal or not — a
    /// habit with an end date still gets a "Day X of Y" alongside it, but as a quiet mono
    /// footnote next to the streak, not a big display-weight number taking over the card.
    private var streakRow: some View {
        HStack(spacing: 10) {
            StreakDotsRow(filled: min(streak, 16), visibility: habit.visibility)
            Text("\(streak) day\(streak == 1 ? "" : "s")")
                .font(KeptFont.mono(12, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
            if hasActiveGoal, let goal = habit.goalDurationDays {
                Spacer()
                Text("Day \(min(habit.daysSinceStart(calendar: calendar), goal)) of \(goal)")
                    .font(KeptFont.mono(11, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            }
        }
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            // Tappable to the habit's photo memories — a sibling to the "⋯" edit
            // button below, not nested inside anything, so it can't swallow or be
            // swallowed by another button's taps.
            Button(action: onPhotosTapped) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(KeptFont.display(18, weight: .semibold))
                        .foregroundStyle(.keptInk)
                    if let subtitle = habit.subtitle(calendar: calendar) {
                        Text(subtitle)
                            .font(KeptFont.body(12, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 4) {
                VisibilityPill(visibility: habit.visibility) {
                    appModel.toggleVisibility(habit)
                }
                Button(action: onEditTapped) {
                    Text("⋯")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private var checkInButton: some View {
        Button(action: onCheckInTapped) {
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(checkInButtonForeground.opacity(0.2))
                    if checkedInToday {
                        Text("✓").font(.system(size: 10))
                    } else if isDownDayToday {
                        // A drawn bar, not a "···" character — at this size that
                        // read too close to the "⋯" more-options glyph used
                        // elsewhere on the same card, despite meaning something
                        // completely different (a paused/down-day status, not a menu).
                        RoundedRectangle(cornerRadius: 1)
                            .fill(checkInButtonForeground)
                            .frame(width: 8, height: 2)
                    }
                }
                .frame(width: 16, height: 16)
                Text(checkedInToday ? "Checked in" : (isDownDayToday ? "Down day" : "Check in today"))
            }
            .font(KeptFont.body(13, weight: .bold))
            .foregroundStyle(checkInButtonForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(checkInButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .sensoryFeedback(.success, trigger: checkedInToday) { _, newValue in newValue }
    }
}
