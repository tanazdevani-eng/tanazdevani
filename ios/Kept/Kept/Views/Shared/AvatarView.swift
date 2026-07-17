import SwiftUI

/// Gradient avatar bubble matching kept.html's .avatar / .avatar.a1-a4 / .avatar.me —
/// a deterministic orange-to-purple gradient keyed by `seed`, with an initial overlaid.
/// There are no profile photos in the mock; the app supports real ones (see
/// EditProfileView) but falls back to this whenever `imageURL` is nil.
struct AvatarView: View {
    let initial: String
    let seed: Int
    var size: CGFloat = 36
    var imageURL: URL? = nil
    /// Shows a Hinge-style small pencil badge + a colored ring instead of the plain white
    /// one, marking the avatar as tappable-to-edit without needing a verification-badge
    /// look-alike.
    var editable: Bool = false

    private var gradient: LinearGradient {
        let variants: [[Color]] = [
            [.keptOrangeDeep, .keptPurpleDeep],
            [Color(hex: 0xC084F5), .keptOrange, .keptPurpleDeep],
            [Color(hex: 0xF5A623), .keptPurple, .keptOrangeDeep],
            [.keptOrange, .keptPurpleDeep],
            [Color(hex: 0xFFA36B), .keptPurpleDeep, .keptOrange],
        ]
        let colors = variants[abs(seed) % variants.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            Circle().fill(gradient)
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Text(initial).foregroundStyle(.white)
                }
                .clipShape(Circle())
            } else {
                Text(initial)
                    .font(KeptFont.display(size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(editable ? Color.keptOrange : .white, lineWidth: editable ? 3 : (size > 60 ? 3 : 1.5)))
        .shadow(color: .black.opacity(0.3), radius: size > 60 ? 10 : 4, y: 3)
        .overlay(alignment: .bottomTrailing) {
            if editable {
                ZStack {
                    Circle().fill(Color.keptInkFill)
                    Text("✎").font(.system(size: size * 0.16)).foregroundStyle(.white)
                }
                .frame(width: size * 0.32, height: size * 0.32)
                .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
    }
}
