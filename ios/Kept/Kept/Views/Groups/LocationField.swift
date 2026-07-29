import SwiftUI
import MapKit

/// Type-and-pick-from-dropdown location input, plus a "use my location" shortcut — the
/// two ways of setting a group's location the founder asked for.
struct LocationField: View {
    @Binding var label: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @StateObject private var completer = LocationSearchCompleter()
    // Plain @State, not @StateObject — LocationFetcher only runs a one-shot async lookup
    // via a continuation and has no @Published state of its own to observe.
    @State private var fetcher = LocationFetcher()
    @State private var isEditing = false
    @State private var isLocating = false
    /// Set right before a resolved pick (dropdown row or "use my location") assigns
    /// `label` programmatically, so the onChange below — which exists to clear stale
    /// coordinates while someone is actually typing — doesn't also fire on that
    /// assignment and immediately null out the coordinates it was just given.
    @State private var isProgrammaticUpdate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("City or area, e.g. New York", text: $label)
                .font(KeptFont.body(15))
                .padding(15)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                .onChange(of: label) { _, newValue in
                    if isProgrammaticUpdate {
                        isProgrammaticUpdate = false
                        return
                    }
                    isEditing = true
                    latitude = nil
                    longitude = nil
                    completer.search(newValue)
                }

            if isEditing && !completer.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(completer.results.prefix(5).enumerated()), id: \.offset) { _, result in
                        Button {
                            Task {
                                if let resolved = await completer.resolve(result) {
                                    isProgrammaticUpdate = true
                                    label = resolved.label
                                    latitude = resolved.latitude
                                    longitude = resolved.longitude
                                }
                                isEditing = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.title).font(KeptFont.body(13, weight: .semibold)).foregroundStyle(.keptInk)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle).font(KeptFont.body(11.5, weight: .medium)).foregroundStyle(.keptInkSoft)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 14)
                    }
                }
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.keptLine))
            }

            Button {
                Task {
                    isLocating = true
                    if let place = await fetcher.currentPlace() {
                        isProgrammaticUpdate = true
                        label = place.label
                        latitude = place.latitude
                        longitude = place.longitude
                        isEditing = false
                    }
                    isLocating = false
                }
            } label: {
                Text(isLocating ? "Finding you..." : "Use my current location")
                    .font(KeptFont.body(12.5, weight: .semibold))
                    .foregroundStyle(.keptOrangeDeep)
            }
            .disabled(isLocating)
        }
    }
}
