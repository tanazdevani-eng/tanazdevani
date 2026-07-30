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

    // A third "not logged" mode used to live here, reached via a "Don't log anything
    // today" button — but backing out of that decision was always just the system back
    // gesture (discards without saving, see the header note above), so the button was a
    // second way to do something you could already do by going back. Removed.
    private enum Mode { case done, downDay }

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
                    Text("Day \(day) · tap the circle to capture a photo")
                        .font(KeptFont.body(12, weight: .medium))
                        .foregroundStyle(.keptInkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 6)

                // Tightened from 28 now that the circle itself is bigger — there was a lot
                // of empty space between the header and the circle before.
                Spacer().frame(height: 14)

                VStack(spacing: 14) {
                    // The circle itself is the camera — tapping it captures a photo rather
                    // than toggling state, since capturing IS the check-in moment now.
                    LiveCameraCircle(
                        ringColor: mode == .done ? .keptSuccess : .keptLine,
                        isDisabled: capturedPhotos.count >= maxPhotos
                    ) { image in
                        capturedPhotos.append(image)
                    }

                    VStack(spacing: 6) {
                        statusChip
                        Text(captureHint)
                            .font(KeptFont.mono(10.5, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                    }

                    // Quick undo for the shot you just took — pops it so the circle's next
                    // tap reshoots into the same slot, instead of needing to scroll down to
                    // the thumbnail strip and tap its "✕" (still there too, for removing an
                    // earlier photo specifically rather than just the most recent one).
                    if !capturedPhotos.isEmpty {
                        Button("Retake last photo") { capturedPhotos.removeLast() }
                            .font(KeptFont.body(12, weight: .semibold))
                            .foregroundStyle(.keptOrangeDeep)
                    }

                    // A real button now (filled pill), not a bare text link — with the
                    // "don't log anything" option gone, this is the only secondary action
                    // left, so there's no mismatched pair to worry about anymore, just one
                    // clearly tappable control.
                    Button(mode == .done ? "Log a down day instead" : "Check in instead") {
                        mode = mode == .done ? .downDay : .done
                    }
                    .font(KeptFont.body(12.5, weight: .semibold))
                    .foregroundStyle(mode == .done ? .keptInkSoft : .keptOrangeDeep)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 16)
                    .background(mode == .done ? Color.keptChip : Color.keptOrangeSoft)
                    .clipShape(Capsule())
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .downDay ? "WHAT GOT IN THE WAY " : "ADD A NOTE ")
                        .font(KeptFont.mono(11, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                    + Text("(optional)")
                        .font(KeptFont.body(11, weight: .regular))
                        .foregroundStyle(.keptInkSoft)

                    TextField(mode == .downDay ? "No pressure, say what happened if you want..." : "Say something about today...", text: $note, axis: .vertical)
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

    /// A colored pill for the status itself (matches the visibility pill / DOWN DAY tag
    /// used elsewhere), with the tap instruction as plain secondary text below it — status
    /// and instruction used to be one flat grey mono line, easy to read past entirely.
    private var statusChip: some View {
        let (label, background, foreground): (String, Color, Color) = {
            switch mode {
            case .done: return ("CHECKED IN", .keptSuccessSoft, .keptSuccess)
            case .downDay: return ("DOWN DAY", .keptChip, .keptInkSoft)
            }
        }()
        return Text(label)
            .font(KeptFont.mono(11, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, 5)
            .padding(.horizontal, 11)
            .background(background)
            .clipShape(Capsule())
    }

    private var captureHint: String {
        capturedPhotos.isEmpty ? "tap to capture" : "tap to capture another"
    }

    private var saveLabel: String {
        mode == .done ? "Save check-in" : "Post down day"
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
                    appModel.showToast(saved ? "Saved to Photos" : "Couldn't save. Check Photos permission.")
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
        }
        dismiss()
    }
}
