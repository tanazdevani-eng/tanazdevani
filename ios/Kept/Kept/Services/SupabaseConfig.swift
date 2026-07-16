import Foundation

/// Fill these in once you've created a Supabase project and run Supabase/schema.sql
/// against it (Project Settings → API in the Supabase dashboard). The anon key is
/// designed to be public/client-side — Supabase's row-level security policies (also in
/// schema.sql) are what actually protect data, not keeping this key secret.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let anonKey = "YOUR-ANON-KEY"

    /// True once the placeholders above have been replaced with real values.
    static var isConfigured: Bool {
        !anonKey.hasPrefix("YOUR-") && !projectURL.absoluteString.contains("YOUR-PROJECT-REF")
    }
}
