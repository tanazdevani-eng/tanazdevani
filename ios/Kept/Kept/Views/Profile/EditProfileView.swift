import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var handle: String = ""
    @State private var bio: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?

    var body: some View {
        // PhotosPicker's label closure is @Sendable, which can't read an actor-isolated
        // property like appModel.profile directly - copying the values to plain locals
        // first sidesteps that instead of fighting the closure's isolation.
        let avatarInitial = appModel.profile.initial
        let avatarURL = appModel.profile.avatarURL

        ScrollView {
            VStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    AvatarView(initial: avatarInitial, seed: 0, size: 88, imageURL: avatarURL, editable: true)
                }
                Text("Change photo")
                    .font(KeptFont.body(12, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                    .underline()
            }
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 0) {
                fieldLabel("Name").padding(.top, 20)
                textField("", text: $name)
                    .autocorrectionDisabled()

                fieldLabel("Username").padding(.top, 16)
                textField("", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                fieldLabel("Bio").padding(.top, 16)
                TextField("", text: $bio, axis: .vertical)
                    .font(KeptFont.body(13.5))
                    .lineLimit(3...6)
                    .padding(14)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))

                Button("Save changes") { save() }
                    .buttonStyle(.keptPrimary)
                    .padding(.top, 26)
                    .padding(.bottom, 90)
            }
        }
        .padding(.horizontal, 22)
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = appModel.profile.name
            handle = appModel.profile.handle
            bio = appModel.profile.bio
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    pickedImageData = data
                }
            }
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(KeptFont.body(15))
            .padding(15)
            .background(.keptSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(11, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    private func save() {
        appModel.updateProfile(
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? appModel.profile.name : name,
            handle: handle.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: ""),
            bio: bio
        )
        if let pickedImageData {
            Task { try? await appModel.uploadAvatar(data: pickedImageData) }
        }
        dismiss()
    }
}
