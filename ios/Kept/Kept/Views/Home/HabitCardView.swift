import SwiftUI

struct HabitCardView: View {
    @EnvironmentObject var appModel: AppModel
    let habit: Habit
    var onCheckInTapped: () -> Void
    var onEditTapped: () -> Void

    private var calendar: DayCalendar { appModel.dayCalendar }
    private var checkedInToday: Bool { habit.isCheckedIn(calendar: calendar) }
    private var streak: Int { habit.streakCount(calendar: calendar) }

    var body: some View {
        KeptCard(fill: AnyShapeStyle(habit.visibility.cardGradient), borderColor: habit.visibility.borderColor, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
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

                HStack(spacing: 10) {
                    StreakDotsRow(filled: min(streak, 16), visibility: habit.visibility)
                    Text("\(streak) day\(streak == 1 ? "" : "s")")
                        .font(KeptFont.mono(12, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                }
                .padding(.top, 14)

                Divider().overlay(Color.keptInk.opacity(0.08)).padding(.top, 12)

                Button(action: onCheckInTapped) {
                    HStack(spacing: 7) {
                        ZStack {
                            Circle().fill(.white.opacity(0.2))
                            if checkedInToday {
                                Text("✓").font(.system(size: 10))
                            }
                        }
                        .frame(width: 16, height: 16)
                        Text(checkedInToday ? "Checked in" : "Check in today")
                    }
                    .font(KeptFont.body(13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(checkedInToday ? Color.keptSuccess : Color.keptInk)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 12)
            }
            .padding(EdgeInsets(top: 18, leading: 18, bottom: 16, trailing: 18))
        }
    }
}
