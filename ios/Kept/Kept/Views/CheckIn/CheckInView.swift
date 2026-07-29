import SwiftUI

/// Tapping "Check in today" on Home already counts as the check-in — this screen opens
/// pre-marked done and lets you add a note or back out of it. The actual commit to
/// AppModel only happens on "Save check-in"; using the system back gesture discards it,
/// matching kept.html's behavior where the back arrow returns home without saving.
struct CheckInView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let habit: Habit

    @State private var isDone = true
    @State private var note = ""
    @FocusState private var noteFocused: Bool

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
                    isDone.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(isDone ? Color.keptSuccess : Color.keptLine, lineWidth: 3)
                            .background(Circle().fill(isDone ? Color.keptSuccessSoft : Color.keptSurface))
                        if isDone {
                            Text("✓").font(.system(size: 44)).foregroundStyle(.keptSuccess)
                        }
                    }
                    .frame(width: 130, height: 130)
                }
                Text(isDone ? "CHECKED IN · tap to undo" : "NOT LOGGED · tap to check in")
                    .font(KeptFont.mono(12, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            }
            .padding(.top, 26)

            VStack(alignment: .leading, spacing: 8) {
                Text("ADD A NOTE ")
                    .font(KeptFont.mono(11, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                + Text("(optional)")
                    .font(KeptFont.body(11, weight: .regular))
                    .foregroundStyle(.keptInkSoft)

                TextField("Say something about today...", text: $note, axis: .vertical)
                    .font(note.isEmpty ? KeptFont.body(13.5) : KeptFont.display(15, italic: true))
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

            visibilityReminder
                .padding(.horizontal, 22)
                .padding(.top, 14)

            Button("Save check-in") { saveCheckIn() }
                .buttonStyle(.keptPrimary)
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 30)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Check in")
        .navigationBarTitleDisplayMode(.inline)
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
        if isDone {
            appModel.checkIn(habit, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            appModel.undoCheckIn(habit)
        }
        dismiss()
    }
}
