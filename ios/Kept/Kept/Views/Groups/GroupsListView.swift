import SwiftUI

struct GroupsListView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingCreateGroup = false
    @State private var searchText = ""
    @State private var selectedGroup: HabitGroup?
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appModel.loadMyGroups()
            await appModel.searchGroups(query: "")
        }
        .sheet(isPresented: $showingCreateGroup) {
            NavigationStack { CreateGroupView() }
        }
        .navigationDestination(item: $selectedGroup) { group in
            GroupDetailView(group: group)
        }
    }

    private func section(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
            content()
        }
    }

    /// Two sibling buttons, not one nested inside the other — nesting a Button in another
    /// Button's label is unreliable (the outer one tends to swallow the inner tap), so the
    /// row-open action and the Join action need to sit next to each other, not stacked.
    private func groupRow(_ group: HabitGroup, showJoin: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedGroup = group
            } label: {
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
                Button {
                    selectedGroup = group
                } label: {
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
