import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var checkInHabit: Habit?
    @State private var editHabit: Habit?

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(appModel.habits) { habit in
                    HabitCardView(
                        habit: habit,
                        onCheckInTapped: { handleCheckInTap(habit) },
                        onEditTapped: { editHabit = habit }
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $checkInHabit) { habit in
            CheckInView(habit: habit)
        }
        .navigationDestination(item: $editHabit) { habit in
            EditHabitView(habit: habit)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Kept").keptWordmark(28).foregroundStyle(.keptInk)
                Spacer()
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Text("🔥").font(.system(size: 12))
                        Text("\(appModel.overallStreak)").font(KeptFont.mono(13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.keptInk)
                    .clipShape(Capsule())

                    Button { appModel.selectedTab = .profile } label: {
                        AvatarView(initial: appModel.profile.initial, seed: 0, size: 34)
                    }
                }
            }
            Text(dateLine)
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private func handleCheckInTap(_ habit: Habit) {
        if habit.isCheckedIn(calendar: appModel.dayCalendar) {
            appModel.undoCheckIn(habit)
        } else {
            checkInHabit = habit
        }
    }
}
