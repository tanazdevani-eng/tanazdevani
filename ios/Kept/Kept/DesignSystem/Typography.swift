import SwiftUI

/// Font access. Requires Fraunces, Inter, and IBM Plex Mono .ttf files to be added under
/// Kept/Resources/Fonts and registered in Info.plist (see project.yml's UIAppFonts list).
/// See ios/Kept/README.md for where to download them.
enum KeptFont {
    static func display(_ size: CGFloat, weight: FrauncesWeight = .semibold, italic: Bool = false) -> Font {
        .custom(italic ? "Fraunces-MediumItalic" : weight.fontName, size: size)
    }

    static func body(_ size: CGFloat, weight: InterWeight = .regular) -> Font {
        .custom(weight.fontName, size: size)
    }

    static func mono(_ size: CGFloat, weight: MonoWeight = .medium) -> Font {
        .custom(weight.fontName, size: size)
    }

    enum FrauncesWeight {
        case regular, medium, semibold

        var fontName: String {
            switch self {
            case .regular: return "Fraunces-Regular"
            case .medium: return "Fraunces-Medium"
            case .semibold: return "Fraunces-SemiBold"
            }
        }
    }

    enum InterWeight {
        case regular, medium, semibold, bold

        var fontName: String {
            switch self {
            case .regular: return "Inter-Regular"
            case .medium: return "Inter-Medium"
            case .semibold: return "Inter-SemiBold"
            case .bold: return "Inter-Bold"
            }
        }
    }

    enum MonoWeight {
        case medium, semibold

        var fontName: String {
            switch self {
            case .medium: return "IBMPlexMono-Medium"
            case .semibold: return "IBMPlexMono-SemiBold"
            }
        }
    }
}

extension Text {
    func keptWordmark(_ size: CGFloat = 28) -> Text {
        self.font(KeptFont.display(size, italic: true))
    }
}
