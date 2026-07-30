import SwiftUI
import UIKit

/// The photo memories grid for one habit — every day a live camera capture was attached at
/// check-in, newest first. Reached by tapping a habit card's name/streak area on Home, so
/// the check-in camera isn't just a momentary Circle post, it's building something you can
/// look back on later.
struct HabitPhotosView: View {
    let habit: Habit
    @EnvironmentObject var appModel: AppModel

    @State private var memories: [HabitCheckInMemory] = []
    @State private var isLoading = true
    @State private var selected: HabitPhotoSelection?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            if memories.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(memories) { memory in
                        ForEach(memory.photoURLs, id: \.self) { url in
                            Button {
                                selected = HabitPhotoSelection(day: memory.day, url: url)
                            } label: {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.keptChip
                                }
                                .aspectRatio(1, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(22)
            }
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            memories = await appModel.fetchCheckInPhotos(habit)
            isLoading = false
        }
        .sheet(item: $selected) { selection in
            HabitPhotoDetailView(day: selection.day, url: selection.url)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(isLoading ? "Loading..." : "No photos yet")
                .font(KeptFont.display(17, weight: .semibold))
                .foregroundStyle(.keptInk)
            if !isLoading {
                Text("Capture one next time you check in. The circle on the check-in screen is a live camera.")
                    .font(KeptFont.body(13, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private struct HabitPhotoSelection: Identifiable {
    var id: URL { url }
    var day: Date
    var url: URL
}

private struct HabitPhotoDetailView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let day: Date
    let url: URL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.keptChip.aspectRatio(1, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(KeptFont.mono(12, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)

                    Button("Save to Photos") {
                        Task {
                            guard let (data, _) = try? await URLSession.shared.data(from: url),
                                  let image = UIImage(data: data) else {
                                appModel.showToast("Couldn't save that photo")
                                return
                            }
                            let saved = await PhotoLibrarySaver.save(image)
                            appModel.showToast(saved ? "Saved to Photos" : "Couldn't save. Check Photos permission.")
                        }
                    }
                    .font(KeptFont.body(13, weight: .semibold))
                    .foregroundStyle(.keptOrangeDeep)
                }
                .padding(22)
            }
            .background(Color.keptBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
