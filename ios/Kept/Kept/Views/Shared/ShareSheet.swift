import SwiftUI
import UIKit

/// Wraps UIActivityViewController directly instead of SwiftUI's ShareLink — ShareLink has
/// no way to know whether someone actually completed a share or backed out of the sheet,
/// only that it was tapped to open it. Anything that needs to act on real completion (like
/// only marking an invite Pending once it's actually been sent, not just attempted) needs
/// this instead.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
