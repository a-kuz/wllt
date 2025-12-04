import SwiftUI

struct MainView: View {
  @EnvironmentObject var walletManager: WalletManager
  @EnvironmentObject var authManager: AuthenticationManager
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      WalletView()
        .tabItem {
          Label("Wallet", systemImage: "wallet.pass")
        }
        .tag(0)

      TransactionsView()
        .tabItem {
          Label("History", systemImage: "list.bullet")
        }
        .tag(1)

      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
        .tag(2)
    }
  }
}
