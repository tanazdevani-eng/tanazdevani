import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingLogoutConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var showingEditProfile = false
    @State private var showingNotifications = false
    @State private var showingManageCircle = false
    @State private var showingInvite = false
    @State private var showingDefaultPrivacy = false
    @State private var showingStreakInsights = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                statRow
                if !appModel.isSubscribed {
                    upgradeBox
                }
                settingsSection(label: "Account") {
                    settingsRow("Edit profile") { showingEditProfile = true }
                    settingsRow("Notifications") { showingNotifications = true }
                    settingsRow("Default habit privacy", value: appModel.defaultVisibility.label) {
                        showingDefaultPrivacy = true
                    }
                }
                settingsSection(label: "Circle") {
                    settingsRow("Invite friends") { showingInvite = true }
                    settingsRow("Manage circle", value: "\(appModel.circleCount)") { showingManageCircle = true }
                }
                settingsSection(label: "Billing") {
                    settingsRow("Manage subscription", value: appModel.isSubscribed ? "Kept+" : "Free") {
                        appModel.showingPaywall = true
                    }
                    settingsRow("Streak insights", value: appModel.isSubscribed ? nil : "Kept+") {
                        showingStreakInsights = true
                    }
                    settingsRow("Log out") { showingLogoutConfirm = true }
                }
                settingsSection(label: "Account") {
                    settingsRow("Delete account", isDestructive: true) { showingDeleteConfirm = true }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showingEditProfile) { EditProfileView() }
        .navigationDestination(isPresented: $showingNotifications) { NotificationsSettingsView() }
        .navigationDestination(isPresented: $showingManageCircle) { ManageCircleView() }
        .navigationDestination(isPresented: $showingInvite) { AddToCircleView() }
        .navigationDestination(isPresented: $showingDefaultPrivacy) { DefaultHabitPrivacyView() }
        .navigationDestination(isPresented: $showingStreakInsights) { StreakInsightsView() }
        .sheet(isPresented: $showingLogoutConfirm) {
            ConfirmSheetContent(
                title: "Log out?",
                message: "You can sign back in any time with the same phone number.",
                destructiveLabel: "Log out",
                isDestructive: false,
                onConfirm: {
                    showingLogoutConfirm = false
                    Task { await appModel.signOut() }
                },
                onCancel: { showingLogoutConfirm = false }
            )
        }
        .sheet(isPresented: $showingDeleteConfirm) {
            ConfirmSheetContent(
                title: "Delete your account permanently?",
                message: "This erases your habits, streaks, and Circle history for good. There's no getting it back. You're welcome to sign up again later with the same phone number.",
                destructiveLabel: "Delete forever",
                onConfirm: {
                    showingDeleteConfirm = false
                    Task { await appModel.deleteAccount() }
                },
                onCancel: { showingDeleteConfirm = false }
            )
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Button { showingEditProfile = true } label: {
                AvatarView(initial: appModel.profile.initial, seed: 0, size: 88, imageURL: appModel.profile.avatarURL, editable: true)
            }
            Text(appModel.profile.name).font(KeptFont.display(21, weight: .semibold)).foregroundStyle(.keptInk)
            Text("@\(appModel.profile.handle)").font(KeptFont.body(12.5, weight: .medium)).foregroundStyle(.keptInkSoft)
            Text(appModel.profile.bio)
                .font(KeptFont.body(12.5, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
                .padding(.top, 2)

            if appModel.isSubscribed {
                Text("KEPT+ MEMBER")
                    .font(KeptFont.mono(10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(Color.keptPurpleFill)
                    .clipShape(Capsule())
                    .padding(.top, 6)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            statBlock(value: "\(appModel.overallStreak)", label: "Day streak")
            Divider().frame(height: 40)
            statBlock(value: "\(appModel.habitsKeptCount)", label: "Habits kept")
            Divider().frame(height: 40)
            statBlock(value: "\(appModel.circleCount)", label: "In circle")
        }
        .padding(.vertical, 14)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))
        .padding(.top, 20)
        .padding(.bottom, 6)
    }

    /// Kept+'s only presence outside a sheet — a single tappable card here instead of a
    /// full tab of its own, since it's an upsell, not a destination someone browses to.
    private var upgradeBox: some View {
        Button { appModel.showingPaywall = true } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("KEPT+")
                        .font(KeptFont.mono(10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Unlimited habits, locks, and streak insights")
                        .font(KeptFont.display(15, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("Upgrade")
                    .font(KeptFont.body(12.5, weight: .bold))
                    .foregroundStyle(.keptPurpleDeep)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.keptPurpleFill, Color.keptPurpleDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(KeptFont.mono(18, weight: .semibold)).foregroundStyle(.keptInk)
            Text(label.uppercased())
                .font(KeptFont.body(10, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private func settingsSection(label: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(KeptFont.mono(10.5, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
                .padding(.top, 20)
                .padding(.bottom, 8)
            VStack(spacing: 0) { rows() }
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))
        }
    }

    // Log out is fully reversible and stays plain ink like every other row; only
    // permanently destructive actions (delete account) get flagged in danger-red — using
    // the same warning color for both blurred a reversible action into looking as
    // consequential as an irreversible one.
    private func settingsRow(_ title: String, value: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(KeptFont.body(13.5, weight: .semibold))
                    .foregroundStyle(isDestructive ? .keptDanger : .keptInk)
                Spacer()
                if let value {
                    Text(value).font(KeptFont.body(13, weight: .medium)).foregroundStyle(.keptInkSoft)
                }
                Text("›").foregroundStyle(.keptInkSoft)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 16)
        }
    }
}
