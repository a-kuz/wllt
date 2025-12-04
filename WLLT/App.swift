import SwiftUI

@main
struct WLLTApp: App {
  @StateObject private var walletManager = WalletManager.shared
  @StateObject private var authManager = AuthenticationManager.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(walletManager)
        .environmentObject(authManager)
    }
  }
}
