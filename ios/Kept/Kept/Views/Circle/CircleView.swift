import SwiftUI

struct CircleView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddToCircle = false
    @State private var showingGroups = false
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
        .navigationDestination(isPresented: $showingGroups) {
            GroupsListView()
        }
    }

    private var header: some View {
        HStack {
            Text("Circle").keptWordmark(28).foregroundStyle(.keptInk)
            Spacer()
            Button { showingGroups = true } label: {
                Text("Groups")
                    .font(KeptFont.body(12.5, weight: .bold))
                    .foregroundStyle(.keptInk)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.keptChip)
                    .clipShape(Capsule())
            }
            Button { showingAddToCircle = true } label: {
                Text("+")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.keptInk)
                    .frame(width: 34, height: 34)
                    .background(Circle().stroke(.keptInk, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
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
