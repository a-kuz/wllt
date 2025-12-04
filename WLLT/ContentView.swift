import SwiftUI

struct ContentView: View {
  @EnvironmentObject var walletManager: WalletManager
  @EnvironmentObject var authManager: AuthenticationManager

  var body: some View {
    Group {
      if walletManager.hasWallet {
        if authManager.isAuthenticated {
          MainView()
        } else {
          AuthenticationView()
        }
      } else {
        WelcomeView()
      }
    }
  }
}
