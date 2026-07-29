import SwiftUI
import PhotosUI
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
    @State private var showingCamera = false
    @State private var libraryItem: PhotosPickerItem?
    private let maxPhotos = 2

    private var day: Int { habit.daysSinceStart(calendar: appModel.dayCalendar) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(KeptFont.display(21, weight: .semibold)).foregroundStyle(.keptInk)
                Text("Day \(day) · tap the circle when it's done")
                    .font(KeptFont.body(12, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 6)

            // Pushes the whole interactive cluster (toggle, note, save) down toward the
            // bottom half of the screen instead of it sitting right under the header —
            // the toggle circle especially was a one-handed reach stretch at the top.
            Spacer(minLength: 16)

            VStack(spacing: 14) {
                Button {
                    mode = (mode == .done) ? .notLogged : .done
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(circleStrokeColor, lineWidth: 3)
                            .background(Circle().fill(circleFillColor))
                        if mode == .done {
                            Text("✓").font(.system(size: 44)).foregroundStyle(.keptSuccess)
                        } else if mode == .downDay {
                            Text("···").font(.system(size: 32, weight: .bold)).foregroundStyle(.keptInkSoft)
                        }
                    }
                    .frame(width: 130, height: 130)
                }
                Text(circleCaption)
                    .font(KeptFont.mono(12, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)

                if mode != .downDay {
                    Button("Couldn't get to this one? Log a down day") { mode = .downDay }
                        .font(KeptFont.body(12, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                        .underline()
                } else {
                    Button("Actually, I did it — check in instead") { mode = .done }
                        .font(KeptFont.body(12, weight: .semibold))
                        .foregroundStyle(.keptOrangeDeep)
                }
            }
            .padding(.top, 26)

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
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            photoRow
                .padding(.horizontal, 22)
                .padding(.top, 14)

            visibilityReminder
                .padding(.horizontal, 22)
                .padding(.top, 14)

            Button(saveLabel) { saveCheckIn() }
                .buttonStyle(.keptPrimary)
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 30)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Check in")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView(
                onCapture: { image in
                    capturedPhotos.append(image)
                    showingCamera = false
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    capturedPhotos.append(image)
                }
                libraryItem = nil
            }
        }
    }

    private var circleStrokeColor: Color {
        switch mode {
        case .done: return .keptSuccess
        case .downDay: return .keptLine
        case .notLogged: return .keptLine
        }
    }

    private var circleFillColor: Color {
        switch mode {
        case .done: return .keptSuccessSoft
        case .downDay: return .keptChip
        case .notLogged: return .keptSurface
        }
    }

    private var circleCaption: String {
        switch mode {
        case .done: return "CHECKED IN · tap to undo"
        case .downDay: return "DOWN DAY · logged, not done"
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

    /// Optional attachment, not a forced simultaneous front/back pair like BeReal —
    /// "Take a photo" opens the stock camera (which already has Apple's own flip-camera
    /// control), "Choose from library" is the PhotosPicker fallback. Someone can attach
    /// one, two (one from each camera if they want, taken separately), or none at all.
    @ViewBuilder private var photoRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !capturedPhotos.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(capturedPhotos.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Button {
                                capturedPhotos.remove(at: index)
                            } label: {
                                Text("✕")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(.black.opacity(0.6)))
                            }
                            .padding(4)
                        }
                    }
                }
            }

            if capturedPhotos.count < maxPhotos {
                HStack(spacing: 16) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take a photo") { showingCamera = true }
                            .font(KeptFont.body(12.5, weight: .semibold))
                            .foregroundStyle(.keptOrangeDeep)
                    }
                    PhotosPicker(selection: $libraryItem, matching: .images) {
                        Text("Choose from library")
                            .font(KeptFont.body(12.5, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)
                    }
                }
            }
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
