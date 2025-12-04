import SwiftUI

struct CreateWalletView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var walletManager: WalletManager
  @State private var seedPhrase: String = ""
  @State private var showingSeedPhrase = false
  @State private var confirmedBackup = false
  @State private var errorMessage: String?
    
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          if showingSeedPhrase {
            seedPhraseView
          } else {
            initialView
          }
        }
        .padding(24)
      }
      .navigationTitle("Create Wallet")
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
    
  private var initialView: some View {
    VStack(spacing: 24) {
      Image(systemName: "key.fill")
        .font(.system(size: 60))
        .foregroundColor(.blue)
            
      Text("Your seed phrase")
        .font(.system(size: 24, weight: .bold))
            
      Text("Write down these 12 words in order. Keep them safe and never share them with anyone.")
        .font(.system(size: 16))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
            
      Button(action: {
        createWallet()
      }) {
        Text("Generate Seed Phrase")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(Color.blue)
          .cornerRadius(12)
      }
            
      if let error = errorMessage {
        Text(error)
          .font(.system(size: 14))
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
      }
    }
  }
    
  private var seedPhraseView: some View {
    VStack(spacing: 24) {
      Text("Write down your seed phrase")
        .font(.system(size: 20, weight: .semibold))
            
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(Array(seedPhrase.split(separator: " ").enumerated()), id: \.offset) { index, word in
          HStack {
            Text("\(index + 1).")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.secondary)
              .frame(width: 30)
            Text(word)
              .font(.system(size: 16, weight: .medium))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(12)
          .background(Color.gray.opacity(0.1))
          .cornerRadius(8)
        }
      }
            
      Button(action: {
        UIPasteboard.general.string = seedPhrase
      }) {
        HStack {
          Image(systemName: "doc.on.doc")
          Text("Copy Seed Phrase")
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.blue)
      }
            
      Toggle("I have written down my seed phrase", isOn: $confirmedBackup)
        .font(.system(size: 16))
            
      Button(action: {
        if confirmedBackup {
          dismiss()
        }
      }) {
        Text("Continue")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(confirmedBackup ? Color.blue : Color.gray)
          .cornerRadius(12)
      }
      .disabled(!confirmedBackup)
    }
  }
    
  private func createWallet() {
    do {
      let generatedSeed = try walletManager.createWallet()
      seedPhrase = generatedSeed
      showingSeedPhrase = true
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
