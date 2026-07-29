import SwiftUI

struct GroupsListView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingCreateGroup = false
    @State private var searchText = ""
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !appModel.myGroups.isEmpty {
                    section(label: "My groups") {
                        ForEach(appModel.myGroups) { group in
                            groupRow(group, showJoin: false)
                        }
                    }
                }

                section(label: "Discover public groups") {
                    TextField("Search by name or location", text: $searchText)
                        .font(KeptFont.body(14))
                        .padding(13)
                        .background(.keptSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.keptLine))
                        .onChange(of: searchText) { _, newValue in
                            Task {
                                isSearching = true
                                await appModel.searchGroups(query: newValue)
                                isSearching = false
                            }
                        }

                    if appModel.discoveredGroups.isEmpty && !isSearching {
                        Text(searchText.isEmpty ? "No public groups yet — be the first to create one." : "No matches.")
                            .font(KeptFont.body(12.5, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                            .padding(.top, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appModel.discoveredGroups.filter { g in !appModel.myGroups.contains(where: { $0.id == g.id }) }) { group in
                                groupRow(group, showJoin: true)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                Button("Create a group") { showingCreateGroup = true }
                    .buttonStyle(.keptPrimary)
                    .padding(.top, 4)
            }
            .padding(22)
            .padding(.bottom, 90)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        // Declared here since this screen is now its own NavigationStack root (its own
        // tab in RootTabView), not pushed inside Circle's stack anymore — a NavigationStack
        // only honors one destination handler per data type, so this is the only place
        // HabitGroup needs one now.
        .navigationDestination(for: HabitGroup.self) { group in
            GroupDetailView(group: group)
        }
        .task {
            await appModel.loadMyGroups()
            await appModel.searchGroups(query: "")
        }
        .sheet(isPresented: $showingCreateGroup) {
            NavigationStack { CreateGroupView() }
        }
    }

    private var header: some View {
        HStack {
            Text("Groups").keptWordmark(28).foregroundStyle(.keptInk)
            Spacer()
            Button { showingCreateGroup = true } label: {
                Text("+")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.keptInk)
                    .frame(width: 34, height: 34)
                    .background(Circle().stroke(.keptInk, lineWidth: 1.5))
            }
        }
        .padding(.top, 4)
    }

    private func section(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
            content()
        }
    }

    /// NavigationLink(value:), matching the destination declared on this screen's own
    /// body above (this view is a NavigationStack root now, not pushed inside another).
    private func groupRow(_ group: HabitGroup, showJoin: Bool) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: group) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(KeptFont.display(15, weight: .semibold))
                        .foregroundStyle(.keptInk)
                    Text("\(group.locationLabel) · \(group.goalSummary)")
                        .font(KeptFont.body(11.5, weight: .medium))
                        .foregroundStyle(.keptInkSoft)
                    Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                        .font(KeptFont.mono(10.5, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showJoin {
                Button("Join") { Task { await appModel.joinGroup(group) } }
                    .font(KeptFont.body(12.5, weight: .bold))
                    .foregroundStyle(.keptOrangeDeep)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.keptOrangeSoft)
                    .clipShape(Capsule())
            } else {
                NavigationLink(value: group) {
                    Text("›").foregroundStyle(.keptInkSoft)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
    }
}
