import Foundation

/// Parsed from a `kept://invite` link someone tapped — either shared generally via
/// "Your invite link" or sent to a specific contact. Presented as an Accept/Decline sheet
/// once the recipient is signed in (see AppModel.incomingInvite and RootTabView's sheet).
struct IncomingInvite: Identifiable, Equatable {
    var inviterId: UUID
    var inviterName: String

    var id: UUID { inviterId }
}
