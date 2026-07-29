import SwiftUI
import UIKit

/// Tapping "Check in today" on Home already counts as the check-in — this screen opens
/// pre-marked done and lets you add a note or back out of it. The actual commit to
/// AppModel only happens on "Save check-in"; using the system back gesture discards it,
/// matching kept.html's behavior where the back arrow returns home without saving.
struct CheckInView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let habit: Habit

    private enum Mode { case done, downDay, notLogged }

    @State private var mode: Mode = .done
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    @State private var capturedPhotos: [UIImage] = []
    private let maxPhotos = 2

    private var day: Int { habit.daysSinceStart(calendar: appModel.dayCalendar) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name).font(KeptFont.display(21, weight: .semibold)).foregroundStyle(.keptInk)
                    Text("Day \(day) · the circle is a live camera — tap it to capture")
                        .font(KeptFont.body(12, weight: .medium))
                        .foregroundStyle(.keptInkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 6)

                // A fixed gap, not an expanding Spacer — the circle still sits a bit lower
                // than directly under the header for easier one-handed reach, but an
                // expanding Spacer here (with nothing below it to balance) ballooned into
                // a huge empty gap on taller screens instead of a modest offset.
                Spacer().frame(height: 28)

                VStack(spacing: 14) {
                    // The circle itself is the camera in .done/.downDay — tapping it
                    // captures a photo rather than toggling the mode, since capturing IS
                    // the check-in moment now. .notLogged has nothing to capture, so it
                    // falls back to the old plain tappable circle.
                    if mode == .notLogged {
                        Button {
                            mode = .done
                        } label: {
                            ZStack {
                                Circle().strokeBorder(Color.keptLine, lineWidth: 3)
                                    .background(Circle().fill(Color.keptSurface))
                            }
                            .frame(width: 130, height: 130)
                        }
                    } else {
                        LiveCameraCircle(
                            ringColor: mode == .done ? .keptSuccess : .keptLine,
                            isDisabled: capturedPhotos.count >= maxPhotos
                        ) { image in
                            capturedPhotos.append(image)
                        }
                    }

                    Text(circleCaption)
                        .font(KeptFont.mono(12, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)

                    // Quick undo for the shot you just took — pops it so the circle's next
                    // tap reshoots into the same slot, instead of needing to scroll down to
                    // the thumbnail strip and tap its "✕" (still there too, for removing an
                    // earlier photo specifically rather than just the most recent one).
                    if !capturedPhotos.isEmpty && mode != .notLogged {
                        Button("Retake last photo") { capturedPhotos.removeLast() }
                            .font(KeptFont.body(12, weight: .semibold))
                            .foregroundStyle(.keptOrangeDeep)
                    }

                    if mode != .notLogged {
                        HStack(spacing: 10) {
                            if mode == .done {
                                Button("Log a down day instead") { mode = .downDay }
                                    .font(KeptFont.body(12.5, weight: .semibold))
                                    .foregroundStyle(.keptInkSoft)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(Color.keptChip)
                                    .clipShape(Capsule())
                            } else {
                                Button("Actually, I did it — check in instead") { mode = .done }
                                    .font(KeptFont.body(12.5, weight: .semibold))
                                    .foregroundStyle(.keptOrangeDeep)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(Color.keptOrangeSoft)
                                    .clipShape(Capsule())
                            }

                            Button("Don't log this") { mode = .notLogged }
                                .font(KeptFont.body(12.5, weight: .semibold))
                                .foregroundStyle(.keptInkSoft)
                        }
                    }
                }
                .padding(.top, 26)

                // Note and photos only make sense for done/down-day — .notLogged means
                // "nothing happened here," so saveCheckIn() calls undoCheckIn(), which
                // takes neither; showing (and silently discarding) either here would be
                // misleading.
                if mode != .notLogged {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode == .downDay ? "WHAT GOT IN THE WAY " : "ADD A NOTE ")
                            .font(KeptFont.mono(11, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)
                        + Text("(optional)")
                            .font(KeptFont.body(11, weight: .regular))
                            .foregroundStyle(.keptInkSoft)

                        TextField(mode == .downDay ? "No pressure — say what happened, if you want..." : "Say something about today...", text: $note, axis: .vertical)
                            .font(note.isEmpty ? KeptFont.body(13.5) : KeptFont.display(15))
                            .foregroundStyle(.keptInk)
                            .focused($noteFocused)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(.keptSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { noteFocused = false }
                                }
                            }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    if !capturedPhotos.isEmpty {
                        photoStrip
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                    }
                }

                visibilityReminder
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                Button(saveLabel) { saveCheckIn() }
                    .buttonStyle(.keptPrimary)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 30)
            }
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Check in")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var circleCaption: String {
        switch mode {
        case .done: return capturedPhotos.isEmpty ? "CHECKED IN · tap to capture" : "CHECKED IN · tap to capture another"
        case .downDay: return capturedPhotos.isEmpty ? "DOWN DAY · tap to capture" : "DOWN DAY · tap to capture another"
        case .notLogged: return "NOT LOGGED · tap to check in"
        }
    }

    private var saveLabel: String {
        switch mode {
        case .done: return "Save check-in"
        case .downDay: return "Post down day"
        case .notLogged: return "Save"
        }
    }

    private var photoStrip: some View {
        HStack(spacing: 10) {
            ForEach(Array(capturedPhotos.enumerated()), id: \.offset) { index, image in
                photoThumbnail(image) { capturedPhotos.remove(at: index) }
            }
        }
    }

    private func photoThumbnail(_ image: UIImage, onRemove: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button(action: onRemove) {
                    Text("✕")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.black.opacity(0.6)))
                }
                .padding(4)
            }
            Button("Save to Photos") {
                Task {
                    let saved = await PhotoLibrarySaver.save(image)
                    appModel.showToast(saved ? "Saved to Photos" : "Couldn't save — check Photos permission")
                }
            }
            .font(KeptFont.body(9.5, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
        }
    }

    @ViewBuilder private var visibilityReminder: some View {
        let isOpen = habit.visibility == .open
        HStack(spacing: 8) {
            Text(isOpen ? "🌐" : "🔒")
            Text(isOpen ? "This will post to your Circle, note and all." : "This stays private. Nothing here reaches your Circle.")
        }
        .font(KeptFont.body(11.5, weight: .semibold))
        .foregroundStyle(isOpen ? .keptOrangeDeep : .keptPurpleDeep)
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isOpen ? Color.keptOrangeSoft : Color.keptPurpleSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func saveCheckIn() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .done:
            appModel.checkIn(habit, note: trimmedNote, photos: capturedPhotos)
        case .downDay:
            appModel.logDownDay(habit, note: trimmedNote.isEmpty ? nil : trimmedNote, photos: capturedPhotos)
        case .notLogged:
            appModel.undoCheckIn(habit)
        }
        dismiss()
    }
}
