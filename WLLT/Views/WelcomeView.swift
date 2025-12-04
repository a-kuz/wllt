import SwiftUI

struct WelcomeView: View {
  @State private var showCreateWallet = false
  @State private var showImportWallet = false
    
  var body: some View {
    NavigationView {
      VStack(spacing: 32) {
        Spacer()
                
        Image(systemName: "wallet.pass")
          .font(.system(size: 80))
          .foregroundColor(.blue)
                
        Text("WLLT")
          .font(.system(size: 48, weight: .bold))
                
        Text("Simple and secure crypto wallet")
          .font(.system(size: 18))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
                
        Spacer()
                
        VStack(spacing: 16) {
          Button(action: {
            showCreateWallet = true
          }) {
            Text("Create Wallet")
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color.blue)
              .cornerRadius(12)
          }
                    
          Button(action: {
            showImportWallet = true
          }) {
            Text("Import Wallet")
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.blue)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color.blue.opacity(0.1))
              .cornerRadius(12)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
      }
      .sheet(isPresented: $showCreateWallet) {
        CreateWalletView()
      }
      .sheet(isPresented: $showImportWallet) {
        ImportWalletView()
      }
    }
  }
}
