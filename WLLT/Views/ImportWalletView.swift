import SwiftUI

struct ImportWalletView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var walletManager: WalletManager
  @State private var seedPhrase: String = ""
  @State private var errorMessage: String?
    
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          Image(systemName: "square.and.arrow.down")
            .font(.system(size: 60))
            .foregroundColor(.blue)
                    
          Text("Import Wallet")
            .font(.system(size: 24, weight: .bold))
                    
          Text("Enter your 12-word seed phrase")
            .font(.system(size: 16))
            .foregroundColor(.secondary)
                    
          TextEditor(text: $seedPhrase)
            .frame(height: 120)
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
                    
          if let error = errorMessage {
            Text(error)
              .font(.system(size: 14))
              .foregroundColor(.red)
              .multilineTextAlignment(.center)
          }
                    
          Button(action: {
            importWallet()
          }) {
            Text("Import")
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color.blue)
              .cornerRadius(12)
          }
        }
        .padding(24)
      }
      .navigationTitle("Import Wallet")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }
    
  private func importWallet() {
    let trimmedSeed = seedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        
    guard !trimmedSeed.isEmpty else {
      errorMessage = "Please enter your seed phrase"
      return
    }
        
    do {
      try walletManager.importWallet(seedPhrase: trimmedSeed)
      dismiss()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
