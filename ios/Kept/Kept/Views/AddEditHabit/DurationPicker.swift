import SwiftUI

struct DurationPicker: View {
    @Binding var selection: HabitDuration
    @State private var customText: String = ""
    @State private var showingCustom: Bool

    init(selection: Binding<HabitDuration>) {
        self._selection = selection
        let initial = selection.wrappedValue
        _showingCustom = State(initialValue: !initial.isPreset)
        if case .days(let n) = initial, !initial.isPreset {
            _customText = State(initialValue: String(n))
        }
    }

    private let presetLabels: [(HabitDuration, String)] = [
        (.ongoing, "Ongoing"), (.days(7), "7 days"), (.days(21), "21 days"),
        (.days(30), "30 days"), (.days(90), "90 days"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(presetLabels, id: \.1) { duration, label in
                    chip(label: label, isSelected: !showingCustom && selection == duration) {
                        showingCustom = false
                        selection = duration
                    }
                }
                chip(label: "Custom", isSelected: showingCustom) {
                    showingCustom = true
                    if let n = Int(customText), n > 0 {
                        selection = .days(n)
                    }
                }
            }

            if showingCustom {
                TextField("Number of days", text: $customText)
                    .keyboardType(.numberPad)
                    .font(KeptFont.body(15))
                    .padding(15)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                    .onChange(of: customText) { _, newValue in
                        if let n = Int(newValue), n > 0 {
                            selection = .days(n)
                        }
                    }
            }

            Text(showingCustom && Int(customText) == nil ? "Enter how many days this goal should run." : selection.note)
                .font(KeptFont.body(11.5, weight: .medium))
                .foregroundStyle(.keptInkSoft)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(KeptFont.body(12.5, weight: .semibold))
                .foregroundStyle(isSelected ? .keptOrangeDeep : .keptInkSoft)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(isSelected ? Color.keptOrangeSoft : .keptSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.keptOrange : Color.keptLine, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

/// Minimal wrapping HStack for the duration chips, matching kept.html's flex-wrap row.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
