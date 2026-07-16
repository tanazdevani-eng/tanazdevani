import SwiftUI

struct VisibilityPicker: View {
    @Binding var selection: HabitVisibility

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HabitVisibility.allCases) { option in
                Button {
                    selection = option
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(option.pillGlyph).font(.system(size: 20))
                        Text(option.label)
                            .font(KeptFont.display(14.5, weight: .semibold))
                            .foregroundStyle(.keptInk)
                        Text(option.pickerDescription)
                            .font(KeptFont.body(11.5, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14))
                    .background(selection == option ? option.accentSoft : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selection == option ? option.accent : Color.keptLine, lineWidth: selection == option ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
