import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var checkInHabit: Habit?
    @State private var editHabit: Habit?
    @State private var photosHabit: Habit?
    @State private var showingStreakInsights = false

    /// Locale-aware instead of a hardcoded US-style "EEEE, MMMM d" template — weekday/month
    /// names, and their order, both vary by language and region.
    private var dateLine: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if appModel.habits.isEmpty {
                    emptyState
                } else {
                    ForEach(appModel.habits) { habit in
                        HabitCardView(
                            habit: habit,
                            onCheckInTapped: { handleCheckInTap(habit) },
                            onEditTapped: { editHabit = habit },
                            onPhotosTapped: { photosHabit = habit }
                        )
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .refreshable { await appModel.refresh() }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(item: $checkInHabit) { habit in
            CheckInView(habit: habit)
        }
        .navigationDestination(item: $editHabit) { habit in
            EditHabitView(habit: habit)
        }
        .navigationDestination(item: $photosHabit) { habit in
            HabitPhotosView(habit: habit)
        }
        .navigationDestination(isPresented: $showingStreakInsights) {
            StreakInsightsView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Kept").keptWordmark(28).foregroundStyle(.keptInk)
                Spacer()
                HStack(spacing: 8) {
                    Button { showingStreakInsights = true } label: {
                        HStack(spacing: 5) {
                            Text("🔥").font(.system(size: 12))
                            Text("\(appModel.overallStreak)").font(KeptFont.mono(13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.keptInkFill)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing kept yet")
                .font(KeptFont.display(19, weight: .semibold))
                .foregroundStyle(.keptInk)
            Text("Tap the + below to add the first thing you want to keep.")
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func handleCheckInTap(_ habit: Habit) {
        if habit.isCheckedIn(calendar: appModel.dayCalendar) {
            appModel.undoCheckIn(habit)
        } else if appModel.downDayHabitIds.contains(habit.id) {
            appModel.undoDownDay(habit)
        } else {
            checkInHabit = habit
        }
    }
}
