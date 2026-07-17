import Foundation

/// Which button someone tapped on the Welcome screen. Phone OTP auth doesn't inherently
/// distinguish "new" from "returning" the way a password does, so this is the signal that
/// decides whether verifying successfully lands in onboarding or straight into the app.
enum AuthIntent: Identifiable, Hashable {
    case signUp
    case logIn

    var id: Self { self }
}
