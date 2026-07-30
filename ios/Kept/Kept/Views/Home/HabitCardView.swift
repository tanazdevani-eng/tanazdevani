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
    /// A habit tracking toward a real end date earns more visual weight than a plain
    /// ongoing one — it becomes this list's natural focal point on its own, rather than
    /// every habit card claiming equal size and attention regardless of what's actually
    /// going on with it.
    private var hasActiveGoal: Bool { habit.goalDurationDays != nil }

    /// Both keptChip and keptSurface were tried here for the down-day state and both read
    /// as an off/washed-out white next to the solid black default and green success fills —
    /// keptMuted is an actual third color (a warm taupe/plum), not another near-white.
    private var checkInButtonBackground: Color {
        if checkedInToday { return .keptSuccess }
        if isDownDayToday { return .keptMuted }
        return .keptInkFill
    }

    private var checkInButtonForeground: Color {
        isDownDayToday && !checkedInToday ? .keptInk : .white
    }

    var body: some View {
        KeptCard(fill: AnyShapeStyle(habit.visibility.cardGradient), borderColor: habit.visibility.borderColor, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 0) {
                topRow

                if hasActiveGoal {
                    goalProgress.padding(.top, 16)
                } else {
                    HStack(spacing: 10) {
                        StreakDotsRow(filled: min(streak, 16), visibility: habit.visibility)
                        Text("\(streak) day\(streak == 1 ? "" : "s")")
                            .font(KeptFont.mono(12, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)
                    }
                    .padding(.top, 14)
                }

                Divider().overlay(Color.keptInk.opacity(0.08)).padding(.top, hasActiveGoal ? 18 : 12)

                checkInButton
                    .padding(.top, 12)
            }
            .padding(EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18))
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
                        .font(KeptFont.display(hasActiveGoal ? 20 : 18, weight: .semibold))
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

    /// Only for habits with a real end date — a big display-weight streak number and a
    /// solid (not soft-tint) progress fill, instead of the same small dots row every habit
    /// gets regardless of whether there's an actual goal behind it. This is what makes this
    /// card the visually dominant one in the list, without needing a separate fake
    /// "featured" banner bolted on above everything.
    private var goalProgress: some View {
        let goal = habit.goalDurationDays ?? 1
        let day = min(habit.daysSinceStart(calendar: calendar), goal)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(streak)")
                    .font(KeptFont.display(32, weight: .semibold))
                    .foregroundStyle(habit.visibility.accentDeep)
                Text("day streak")
                    .font(KeptFont.body(13, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.keptChip)
                    Capsule()
                        .fill(habit.visibility.accentFill)
                        .frame(width: geo.size.width * CGFloat(day) / CGFloat(max(goal, 1)))
                }
            }
            .frame(height: 8)
            HStack {
                Text("Day \(day)").font(KeptFont.mono(11.5, weight: .semibold)).foregroundStyle(.keptInkSoft)
                Spacer()
                Text("of \(goal)").font(KeptFont.mono(11.5, weight: .semibold)).foregroundStyle(.keptInkSoft)
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
            .padding(.vertical, hasActiveGoal ? 13 : 11)
            .background(checkInButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .sensoryFeedback(.success, trigger: checkedInToday) { _, newValue in newValue }
    }
}
