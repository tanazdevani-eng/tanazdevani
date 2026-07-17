import SwiftUI

@main
struct KeptApp: App {
    @StateObject private var storeKit: StoreKitManager
    @StateObject private var appModel: AppModel

    init() {
        let storeKitManager = StoreKitManager()
        let backend: BackendService = SupabaseConfig.isConfigured
            ? SupabaseBackendService(url: SupabaseConfig.projectURL, anonKey: SupabaseConfig.anonKey)
            : MockBackendService()
        _storeKit = StateObject(wrappedValue: storeKitManager)
        _appModel = StateObject(wrappedValue: AppModel(backend: backend, storeKit: storeKitManager))
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(appModel)
                .environmentObject(storeKit)
                .task { await appModel.checkExistingSession() }
        }
    }
}
