import SwiftUI

/// Lets you fix or clear the note on your own check-in without undoing the check-in
/// itself — reachable by tapping the note (or the "no note" placeholder) on your own
/// Circle post.
struct EditNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialText: String
    let onSave: (String?) -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(initialText: String, onSave: @escaping (String?) -> Void) {
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit note")
                .font(KeptFont.display(20, weight: .semibold))
                .foregroundStyle(.keptInk)

            // Same corner radius as the check-in screen's own note field — this and
            // CheckInView used to be the two different treatments of the identical
            // "add a note" affordance.
            TextField("Say something about today...", text: $text, axis: .vertical)
                .font(KeptFont.body(14))
                .focused($focused)
                .lineLimit(3...6)
                .padding(14)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
                .padding(.top, 16)

            Button("Save") {
                onSave(text)
                dismiss()
            }
            .buttonStyle(.keptPrimary)
            .padding(.top, 20)

            if !initialText.isEmpty {
                // Was marked role: .destructive but then manually recolored orange,
                // contradicting its own role — a real destructive action (clears the note
                // for good) should actually look like one.
                Button("Remove note", role: .destructive) {
                    onSave(nil)
                    dismiss()
                }
                .font(KeptFont.body(13, weight: .semibold))
                .foregroundStyle(.keptDanger)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
            }
        }
        .padding(22)
        .padding(.top, 14)
        .background(Color.keptBackground.ignoresSafeArea())
        .presentationDetents([.height(initialText.isEmpty ? 260 : 310)])
        .onAppear { focused = true }
    }
}
