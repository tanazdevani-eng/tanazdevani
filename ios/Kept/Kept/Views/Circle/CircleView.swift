import SwiftUI

struct CircleView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddToCircle = false
    @State private var showingGroups = false
    @State private var showingCreateGroup = false
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

                groupsSection

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
        // Declared once here, at the actual NavigationStack root (RootTabView wraps
        // CircleView directly in a NavigationStack) — GroupsListView is pushed onto this
        // same stack and reuses this single destination via NavigationLink(value:) rather
        // than declaring its own, since a NavigationStack only honors one destination
        // handler per data type across its whole hierarchy.
        .navigationDestination(for: HabitGroup.self) { group in
            GroupDetailView(group: group)
        }
        .sheet(isPresented: $showingCreateGroup) {
            NavigationStack { CreateGroupView() }
        }
        .task { await appModel.loadMyGroups() }
    }

    private var header: some View {
        HStack {
            Text("Circle").keptWordmark(28).foregroundStyle(.keptInk)
            Spacer()
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

    /// Groups are a real part of Circle, not a hidden destination — embedded as its own
    /// horizontal row right in the feed instead of a tiny top-right nav pill, whether or
    /// not you've joined one yet.
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GROUPS")
                    .font(KeptFont.mono(11, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                Spacer()
                Button("Create") { showingCreateGroup = true }
                    .font(KeptFont.body(12, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                Button("See all") { showingGroups = true }
                    .font(KeptFont.body(12, weight: .semibold))
                    .foregroundStyle(.keptOrangeDeep)
            }
            .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appModel.myGroups) { group in
                        NavigationLink(value: group) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(KeptFont.body(13, weight: .bold))
                                    .foregroundStyle(.keptInk)
                                Text(group.goalSummary)
                                    .font(KeptFont.mono(10.5, weight: .semibold))
                                    .foregroundStyle(.keptInkSoft)
                                Text(group.locationLabel)
                                    .font(KeptFont.body(11, weight: .medium))
                                    .foregroundStyle(.keptInkSoft)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(14)
                            .background(Color.keptOrangeSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showingGroups = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appModel.myGroups.isEmpty ? "Find your people" : "Discover more")
                                .font(KeptFont.body(13, weight: .bold))
                                .foregroundStyle(.keptInk)
                            Text("Public groups tied to a real place and a shared goal")
                                .font(KeptFont.body(11, weight: .medium))
                                .foregroundStyle(.keptInkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 150, alignment: .leading)
                        .padding(14)
                        .background(.keptSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
            }
        }
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
