import Foundation
import Supabase

/// Single shared Supabase client for the whole app.
enum Backend {
    static let client = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabasePublishableKey
    )
}
