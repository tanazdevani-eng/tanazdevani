import SwiftUI

struct CountryCodePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: CountryCode
    @State private var searchText = ""

    private var filtered: [CountryCode] {
        guard !searchText.isEmpty else { return CountryCode.all }
        return CountryCode.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.dialCode.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selection = country
                    dismiss()
                } label: {
                    HStack {
                        Text(country.name)
                            .font(KeptFont.body(14.5, weight: .medium))
                            .foregroundStyle(.keptInk)
                        Spacer()
                        Text(country.dialCode)
                            .font(KeptFont.mono(13, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                        if country == selection {
                            Text("✓").foregroundStyle(.keptOrangeDeep)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
