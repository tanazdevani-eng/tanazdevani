import SwiftUI

/// A real, scrollable wheel for picking a time — replaces the old "tap to cycle through a
/// handful of fixed presets" chip, which had no way to land on anything outside that list
/// (e.g. 7:15am). showsMinute off gives an hour-only wheel for Day reset, where minutes
/// don't apply.
struct TimeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let showsMinute: Bool
    let onSave: (DateComponents) -> Void

    @State private var date: Date

    init(title: String, initialComponents: DateComponents, showsMinute: Bool, onSave: @escaping (DateComponents) -> Void) {
        self.title = title
        self.showsMinute = showsMinute
        self.onSave = onSave
        let base = Calendar.current.date(
            bySettingHour: initialComponents.hour ?? 0,
            minute: initialComponents.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()
        _date = State(initialValue: base)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(KeptFont.display(18, weight: .semibold))
                .foregroundStyle(.keptInk)
                .padding(.top, 8)

            Group {
                if showsMinute {
                    DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                } else {
                    Picker("", selection: hourBinding) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
            }
            .padding(.top, 4)

            Button("Done") {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                onSave(showsMinute ? comps : DateComponents(hour: comps.hour, minute: 0))
                dismiss()
            }
            .buttonStyle(.keptPrimary)
            .padding(.top, 12)
        }
        .padding(22)
        .background(Color.keptBackground.ignoresSafeArea())
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: date) },
            set: { newHour in
                date = Calendar.current.date(bySettingHour: newHour, minute: 0, second: 0, of: date) ?? date
            }
        )
    }

    private func hourLabel(_ hour: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        var displayHour = hour % 12
        if displayHour == 0 { displayHour = 12 }
        return String(format: "%d:00 %@", displayHour, period)
    }
}
