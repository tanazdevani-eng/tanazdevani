import Foundation

/// Dial codes for phone sign-in — the old logic assumed every number was a bare 10-digit
/// US number, which silently produced a garbage E.164 number for anyone outside the US.
/// This is real reference data (ITU-T E.164 calling codes), not something that needs
/// per-market localization the way UI copy does.
struct CountryCode: Identifiable, Equatable, Hashable {
    let region: String
    let name: String
    let dialCode: String

    var id: String { region }

    /// Picks the country matching the device's current region, falling back to the US —
    /// most people signing up will never need to touch the picker at all.
    static func detected() -> CountryCode {
        let regionCode = Locale.current.region?.identifier
        return all.first { $0.region == regionCode } ?? unitedStates
    }

    static let unitedStates = CountryCode(region: "US", name: "United States", dialCode: "+1")

    static let all: [CountryCode] = [
        CountryCode(region: "US", name: "United States", dialCode: "+1"),
        CountryCode(region: "CA", name: "Canada", dialCode: "+1"),
        CountryCode(region: "MX", name: "Mexico", dialCode: "+52"),
        CountryCode(region: "GB", name: "United Kingdom", dialCode: "+44"),
        CountryCode(region: "IE", name: "Ireland", dialCode: "+353"),
        CountryCode(region: "FR", name: "France", dialCode: "+33"),
        CountryCode(region: "DE", name: "Germany", dialCode: "+49"),
        CountryCode(region: "ES", name: "Spain", dialCode: "+34"),
        CountryCode(region: "PT", name: "Portugal", dialCode: "+351"),
        CountryCode(region: "IT", name: "Italy", dialCode: "+39"),
        CountryCode(region: "NL", name: "Netherlands", dialCode: "+31"),
        CountryCode(region: "BE", name: "Belgium", dialCode: "+32"),
        CountryCode(region: "CH", name: "Switzerland", dialCode: "+41"),
        CountryCode(region: "AT", name: "Austria", dialCode: "+43"),
        CountryCode(region: "SE", name: "Sweden", dialCode: "+46"),
        CountryCode(region: "NO", name: "Norway", dialCode: "+47"),
        CountryCode(region: "DK", name: "Denmark", dialCode: "+45"),
        CountryCode(region: "FI", name: "Finland", dialCode: "+358"),
        CountryCode(region: "IS", name: "Iceland", dialCode: "+354"),
        CountryCode(region: "PL", name: "Poland", dialCode: "+48"),
        CountryCode(region: "CZ", name: "Czechia", dialCode: "+420"),
        CountryCode(region: "SK", name: "Slovakia", dialCode: "+421"),
        CountryCode(region: "HU", name: "Hungary", dialCode: "+36"),
        CountryCode(region: "RO", name: "Romania", dialCode: "+40"),
        CountryCode(region: "BG", name: "Bulgaria", dialCode: "+359"),
        CountryCode(region: "GR", name: "Greece", dialCode: "+30"),
        CountryCode(region: "HR", name: "Croatia", dialCode: "+385"),
        CountryCode(region: "SI", name: "Slovenia", dialCode: "+386"),
        CountryCode(region: "RS", name: "Serbia", dialCode: "+381"),
        CountryCode(region: "UA", name: "Ukraine", dialCode: "+380"),
        CountryCode(region: "LT", name: "Lithuania", dialCode: "+370"),
        CountryCode(region: "LV", name: "Latvia", dialCode: "+371"),
        CountryCode(region: "EE", name: "Estonia", dialCode: "+372"),
        CountryCode(region: "RU", name: "Russia", dialCode: "+7"),
        CountryCode(region: "TR", name: "Turkey", dialCode: "+90"),
        CountryCode(region: "IL", name: "Israel", dialCode: "+972"),
        CountryCode(region: "AE", name: "United Arab Emirates", dialCode: "+971"),
        CountryCode(region: "SA", name: "Saudi Arabia", dialCode: "+966"),
        CountryCode(region: "QA", name: "Qatar", dialCode: "+974"),
        CountryCode(region: "KW", name: "Kuwait", dialCode: "+965"),
        CountryCode(region: "EG", name: "Egypt", dialCode: "+20"),
        CountryCode(region: "ZA", name: "South Africa", dialCode: "+27"),
        CountryCode(region: "NG", name: "Nigeria", dialCode: "+234"),
        CountryCode(region: "KE", name: "Kenya", dialCode: "+254"),
        CountryCode(region: "GH", name: "Ghana", dialCode: "+233"),
        CountryCode(region: "MA", name: "Morocco", dialCode: "+212"),
        CountryCode(region: "IN", name: "India", dialCode: "+91"),
        CountryCode(region: "PK", name: "Pakistan", dialCode: "+92"),
        CountryCode(region: "BD", name: "Bangladesh", dialCode: "+880"),
        CountryCode(region: "LK", name: "Sri Lanka", dialCode: "+94"),
        CountryCode(region: "NP", name: "Nepal", dialCode: "+977"),
        CountryCode(region: "CN", name: "China", dialCode: "+86"),
        CountryCode(region: "JP", name: "Japan", dialCode: "+81"),
        CountryCode(region: "KR", name: "South Korea", dialCode: "+82"),
        CountryCode(region: "TW", name: "Taiwan", dialCode: "+886"),
        CountryCode(region: "HK", name: "Hong Kong", dialCode: "+852"),
        CountryCode(region: "SG", name: "Singapore", dialCode: "+65"),
        CountryCode(region: "MY", name: "Malaysia", dialCode: "+60"),
        CountryCode(region: "TH", name: "Thailand", dialCode: "+66"),
        CountryCode(region: "VN", name: "Vietnam", dialCode: "+84"),
        CountryCode(region: "PH", name: "Philippines", dialCode: "+63"),
        CountryCode(region: "ID", name: "Indonesia", dialCode: "+62"),
        CountryCode(region: "AU", name: "Australia", dialCode: "+61"),
        CountryCode(region: "NZ", name: "New Zealand", dialCode: "+64"),
        CountryCode(region: "BR", name: "Brazil", dialCode: "+55"),
        CountryCode(region: "AR", name: "Argentina", dialCode: "+54"),
        CountryCode(region: "CL", name: "Chile", dialCode: "+56"),
        CountryCode(region: "CO", name: "Colombia", dialCode: "+57"),
        CountryCode(region: "PE", name: "Peru", dialCode: "+51"),
        CountryCode(region: "EC", name: "Ecuador", dialCode: "+593"),
        CountryCode(region: "UY", name: "Uruguay", dialCode: "+598"),
        CountryCode(region: "PY", name: "Paraguay", dialCode: "+595"),
        CountryCode(region: "BO", name: "Bolivia", dialCode: "+591"),
        CountryCode(region: "VE", name: "Venezuela", dialCode: "+58"),
        CountryCode(region: "CR", name: "Costa Rica", dialCode: "+506"),
        CountryCode(region: "PA", name: "Panama", dialCode: "+507"),
        CountryCode(region: "DO", name: "Dominican Republic", dialCode: "+1"),
        CountryCode(region: "JM", name: "Jamaica", dialCode: "+1"),
        CountryCode(region: "TT", name: "Trinidad and Tobago", dialCode: "+1"),
    ].sorted { $0.name < $1.name }
}
