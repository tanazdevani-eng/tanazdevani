import SwiftUI
import UIKit
import AVFoundation

/// Runs an AVCaptureSession and exposes it as a live preview + tap-to-capture — this is
/// deliberately Apple's lower-level camera framework, not UIImagePickerController, because
/// the whole point is showing the live feed inline inside a small circle on the check-in
/// screen (with the rest of the page still visible around it) rather than taking over the
/// full screen.
///
/// Deliberately NOT @MainActor: every session-touching method (start/stop/flip/capture,
/// and the private input/config helpers) does its actual work on `sessionQueue`, a
/// dedicated serial background queue — matching Apple's own guidance that
/// startRunning()/stopRunning() are blocking calls that shouldn't run on the main thread.
/// Marking the class @MainActor while dispatching its own methods onto a plain GCD queue
/// type-checks (the compiler can't see GCD hopping threads) but is misleading: the code
/// would silently execute off the main thread despite looking actor-isolated. Leaving the
/// class unisolated and only hopping to `@MainActor` for the two things that actually need
/// it — publishing `isAuthorized` and invoking the SwiftUI-facing capture completion —
/// keeps what the compiler asserts honest about what actually happens at runtime.
enum CameraAuthState { case notDetermined, authorized, denied }

final class CircleCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    /// Three states, not a bool — .notDetermined and .denied need different taps (request
    /// vs. deep-link to Settings), so the view needs to tell them apart.
    @Published var authState: CameraAuthState = .notDetermined

    private let sessionQueue = DispatchQueue(label: "kept.circleCamera.session")
    private let photoOutput = AVCapturePhotoOutput()
    /// Only ever read/written from within sessionQueue.async blocks (never directly), so
    /// the serial queue is what actually makes access to these safe.
    private var currentInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var captureCompletion: ((UIImage?) -> Void)?

    /// Just reads the current status — deliberately does NOT call requestAccess itself.
    /// The system permission dialog should only appear because someone tapped something
    /// asking for it (requestAccess() below), not the instant this screen loads; showing
    /// it unprompted on appear is exactly the "ambushed by a system alert" feeling that
    /// isn't seamless.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authState = .authorized
            configureAndRun()
        case .notDetermined:
            authState = .notDetermined
        default:
            authState = .denied
        }
    }

    /// Called from a tap on the circle itself when authState is .notDetermined — the
    /// system dialog appears as a direct result of that tap, not automatically.
    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.authState = granted ? .authorized : .denied
                if granted { self?.configureAndRun() }
            }
        }
    }

    /// Re-checks permission after, e.g., the user grants camera access in Settings and
    /// returns to the app — start() only runs once from .onAppear, so without this a
    /// denied-then-granted permission change wouldn't be picked up until the view itself
    /// was torn down and recreated.
    func recheckAuthorizationIfNeeded() {
        guard authState != .authorized, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        authState = .authorized
        configureAndRun()
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func flipCamera() {
        sessionQueue.async { [self] in
            let nextPosition: AVCaptureDevice.Position = (currentInput?.device.position == .front) ? .back : .front
            session.beginConfiguration()
            addInput(position: nextPosition)
            session.commitConfiguration()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        sessionQueue.async { [photoOutput, self] in
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    /// Runs entirely on sessionQueue.
    private func configureAndRun() {
        sessionQueue.async { [self] in
            if !isConfigured {
                session.beginConfiguration()
                session.sessionPreset = .photo
                addInput(position: .back)
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                }
                session.commitConfiguration()
                isConfigured = true
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    /// Must be called on sessionQueue — begins/commitConfiguration around this is the
    /// caller's responsibility (both call sites above already wrap it that way).
    private func addInput(position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if let currentInput { session.removeInput(currentInput) }
        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }
    }

    /// AVFoundation invokes this on its own internal delegate queue, not necessarily the
    /// main thread — hopping to @MainActor before touching captureCompletion is what makes
    /// it safe for that closure to go on and mutate SwiftUI @State in LiveCameraCircle.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image: UIImage? = {
            guard error == nil, let data = photo.fileDataRepresentation() else { return nil }
            return UIImage(data: data)
        }()
        Task { @MainActor in
            self.captureCompletion?(image)
            self.captureCompletion = nil
        }
    }
}

private struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}

    final class PreviewContainerView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// The check-in circle itself, reimagined as a live camera feed you tap to capture —
/// instead of a static checkmark you tap to toggle done/undone. Starts/stops its session
/// with the view's lifecycle so the camera isn't left running once you've moved on.
struct LiveCameraCircle: View {
    var ringColor: Color
    var isDisabled: Bool = false
    var onCapture: (UIImage) -> Void

    @StateObject private var controller = CircleCameraController()
    @State private var isCapturing = false
    @State private var justCaptured = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Two sibling buttons (capture + flip), not one nested inside the other's label —
        // nesting a Button inside another Button's label makes the outer one swallow taps
        // meant for the inner one (learned the hard way earlier on the Groups screens).
        ZStack(alignment: .bottomTrailing) {
            Button {
                switch controller.authState {
                case .authorized:
                    guard !isCapturing && !isDisabled else { return }
                    isCapturing = true
                    controller.capturePhoto { image in
                        isCapturing = false
                        if let image {
                            onCapture(image)
                            justCaptured = true
                            Task {
                                try? await Task.sleep(for: .milliseconds(500))
                                justCaptured = false
                            }
                        }
                    }
                case .notDetermined:
                    // The system dialog fires as a direct result of this tap, not
                    // automatically on appear — that's what makes it feel requested
                    // rather than an ambush.
                    controller.requestAccess()
                case .denied:
                    // One tap straight to Kept's Settings page instead of making someone
                    // hunt through Settings > Privacy > Camera manually — as close to
                    // "grant access from the app" as iOS actually allows; Apple doesn't
                    // permit a true in-app permission toggle.
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } label: {
                ZStack {
                    if controller.authState == .authorized {
                        CameraPreviewLayerView(session: controller.session)
                    } else {
                        Circle().fill(Color.keptChip)
                    }
                    if justCaptured {
                        Circle().fill(.black.opacity(0.35))
                        Text("✓").font(.system(size: 44, weight: .bold)).foregroundStyle(.white)
                    } else if controller.authState == .notDetermined {
                        Text("Tap to enable\ncamera")
                            .font(KeptFont.body(10, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)
                            .multilineTextAlignment(.center)
                    } else if controller.authState == .denied {
                        Text("Tap to enable\ncamera in Settings")
                            .font(KeptFont.body(10, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 130, height: 130)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(ringColor, lineWidth: 3))
                .opacity(isDisabled && controller.authState == .authorized ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled && controller.authState == .authorized)

            if controller.authState == .authorized {
                Button {
                    controller.flipCamera()
                } label: {
                    Text("Flip")
                        .font(KeptFont.body(9.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: -6)
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
        .onChange(of: scenePhase) { _, newPhase in
            // Catches "denied, then granted it in Settings, then came back" — start()
            // only ever runs once from onAppear, so without this the circle would keep
            // showing the "enable in Settings" state even after permission was granted.
            if newPhase == .active {
                controller.recheckAuthorizationIfNeeded()
            }
        }
    }
}
