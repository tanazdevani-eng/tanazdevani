import SwiftUI

struct CircleView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddToCircle = false
    /// Shown until dismissed once, then remembered — a reminder worth seeing the first
    /// few times you're on this screen, not something that should sit here forever once
    /// you already know Kept habits never show up in Circle.
    @AppStorage("hasSeenCirclePrivacyNote") private var hasSeenPrivacyNote = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                Text("The habits your friends have chosen to open up. Everything else stays theirs.")
                    .font(KeptFont.body(13, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.horizontal, 22)

                if !uncheckedHabitsToday.isEmpty {
                    unfinishedHabitsBanner
                        .padding(.horizontal, 22)
                }

                if appModel.circleFeed.isEmpty {
                    emptyState
                        .padding(.horizontal, 22)
                } else {
                    ForEach(appModel.circleFeed) { item in
                        FriendPostCard(item: item)
                            .padding(.horizontal, 22)
                    }
                }

                if !hasSeenPrivacyNote {
                    lockedNote
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 110)
        }
        .refreshable { await appModel.refresh() }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showingAddToCircle) {
            AddToCircleView()
        }
    }

    private var header: some View {
        HStack {
            Text("Circle").keptWordmark(28).foregroundStyle(.keptInk)
            Spacer()
            // A labeled pill, not a bare "+" — the tab bar already has its own "+" (always
            // Add Habit) sitting right below; a second, different-meaning "+" glyph up here
            // read as the same button doing two different things.
            Button("Invite") { showingAddToCircle = true }
                .font(KeptFont.body(12.5, weight: .bold))
                .foregroundStyle(.keptInk)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .overlay(Capsule().strokeBorder(.keptInk, lineWidth: 1.5))
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }

    /// Circle is the front door now, but a static habit list one tab over has nothing
    /// pulling you back to it on its own — this bridges the gap so the personal action is
    /// never more than a glance away even though the feed opens first.
    private var uncheckedHabitsToday: [Habit] {
        appModel.habits.filter {
            !$0.isCheckedIn(calendar: appModel.dayCalendar) && !appModel.downDayHabitIds.contains($0.id)
        }
    }

    private var unfinishedHabitsBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(uncheckedHabitsToday.count == 1 ? "1 habit waiting on you today" : "\(uncheckedHabitsToday.count) habits waiting on you today")
                    .font(KeptFont.body(13, weight: .bold))
                    .foregroundStyle(.keptInk)
                Text(uncheckedHabitsToday.count == 1 ? uncheckedHabitsToday[0].name : "Check in before the day resets.")
                    .font(KeptFont.body(11.5, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
            }
            Spacer(minLength: 8)
            Button("Check in") { appModel.selectedTab = .habits }
                .font(KeptFont.body(12.5, weight: .bold))
                .foregroundStyle(.keptOrangeDeep)
                .padding(.vertical, 9)
                .padding(.horizontal, 16)
                .background(Color.keptOrangeSoft)
                .clipShape(Capsule())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Quiet in here")
                .font(KeptFont.display(19, weight: .semibold))
                .foregroundStyle(.keptInk)
            Text("Add people to your circle, then check in on an Open habit and it'll show up here.")
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Button("Add to your circle") { showingAddToCircle = true }
                .buttonStyle(.keptPrimary)
                .padding(.horizontal, 40)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var lockedNote: some View {
        HStack(spacing: 10) {
            Text("🔒")
            Text("Your circle can't see anything marked \u{201C}Kept.\u{201D} Not the streak, not the name. Nothing.")
                .font(KeptFont.body(12, weight: .semibold))
                .foregroundStyle(.keptPurpleDeep)
            Spacer(minLength: 0)
            Button {
                hasSeenPrivacyNote = true
            } label: {
                Text("✕").font(.system(size: 12, weight: .semibold)).foregroundStyle(.keptPurpleDeep)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.keptPurpleSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
