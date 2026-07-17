import SwiftUI
import UIKit

/// Pinch-to-zoom, drag-to-reposition crop step shown right after picking a photo — most
/// photo pickers include this and landing straight on an uncropped, unadjusted image would
/// be a step backward from what people expect.
struct AvatarCropView: View {
    @Environment(\.dismiss) private var dismiss
    let imageData: Data
    let onCropped: (Data) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280
    private var uiImage: UIImage? { UIImage(data: imageData) }

    var body: some View {
        VStack(spacing: 0) {
            Text("Adjust photo")
                .font(KeptFont.display(19, weight: .semibold))
                .foregroundStyle(.keptInk)
                .padding(.top, 18)
            Text("Pinch to zoom, drag to reposition")
                .font(KeptFont.body(12.5, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .padding(.top, 4)
                .padding(.bottom, 24)

            cropCircle
                .padding(.top, 4)

            Spacer()

            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(KeptPillButtonStyle(background: .keptBackground, foreground: .keptInkSoft, borderColor: .keptLine))
                Button("Use Photo") { cropAndSave() }
                    .buttonStyle(.keptPrimary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .background(Color.keptBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var cropCircle: some View {
        if let uiImage {
            croppableImage(uiImage)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in scale = min(4, max(1, lastScale * value)) }
                            .onEnded { _ in lastScale = scale },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                )
        } else {
            Circle().fill(Color.keptSurface).frame(width: cropSize, height: cropSize)
        }
    }

    private func croppableImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: cropSize, height: cropSize)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: cropSize, height: cropSize)
            .clipped()
    }

    private func cropAndSave() {
        guard let uiImage else { dismiss(); return }
        let renderer = ImageRenderer(content: croppableImage(uiImage))
        renderer.scale = UIScreen.main.scale
        if let rendered = renderer.uiImage, let data = rendered.jpegData(compressionQuality: 0.85) {
            onCropped(data)
        }
        dismiss()
    }
}
