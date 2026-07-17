import SwiftUI

/// This used to be a silent instant-toggle behind a row that visually promised a "›"
/// destination like every other settings row — tapping it "did" something (the value
/// changed), but with no screen to land on, it read as broken/unresponsive. A real screen
/// matches the affordance it's already showing.
struct DefaultHabitPrivacyView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New habits you add will start with this visibility. You can always change it per habit afterward.")
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .padding(.bottom, 20)

            VisibilityPicker(selection: Binding(
                get: { appModel.defaultVisibility },
                set: { newValue in
                    if newValue != appModel.defaultVisibility {
                        appModel.toggleDefaultVisibility()
                    }
                }
            ))

            Spacer()
        }
        .padding(22)
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Default habit privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
