import SwiftUI

struct CreateWalletView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.scenePhase) var scenePhase
  @EnvironmentObject var walletManager: WalletManager
  @EnvironmentObject var authManager: AuthenticationManager
  @State private var seedPhrase: String = ""
  @State private var showingSeedPhrase = false
  @State private var confirmedBackup = false
  @State private var errorMessage: String?
  @State private var isSeedPhraseRevealed = false
  @State private var isAppInBackground = false
  @State private var showCopyWarning = false
    
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
      .onChange(of: scenePhase) { newPhase in
        if newPhase != .active && showingSeedPhrase {
          isAppInBackground = true
          isSeedPhraseRevealed = false
        } else if newPhase == .active {
          isAppInBackground = false
        }
      }
      .alert("Security Warning", isPresented: $showCopyWarning) {
        Button("Cancel", role: .cancel) {}
        Button("Copy Anyway") {
          UIPasteboard.general.string = seedPhrase
        }
      } message: {
        Text("Copying your seed phrase to clipboard is not secure. Anyone with access to your clipboard can see it. Only copy if you are in a completely private environment.")
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
      VStack(spacing: 12) {
        Image(systemName: "exclamationmark.shield.fill")
          .font(.system(size: 50))
          .foregroundColor(.orange)
        
        Text("Your Seed Phrase")
          .font(.system(size: 24, weight: .bold))
        
        Text("Never share your seed phrase with anyone. Anyone with access to it can control your wallet. Write it down on paper and store it securely.")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 8)
      }
      
      if !seedPhrase.isEmpty {
        VStack(spacing: 16) {
          if isAppInBackground {
            VStack(spacing: 12) {
              Image(systemName: "eye.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
              Text("Content hidden for security")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
              Text("Tap to reveal seed phrase again")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .contentShape(Rectangle())
            .onTapGesture {
              isAppInBackground = false
            }
          } else if !isSeedPhraseRevealed {
            VStack(spacing: 12) {
              Image(systemName: "eye.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
              Text("Tap to reveal your seed phrase")
                .font(.system(size: 16, weight: .medium))
              Text("Make sure no one can see your screen")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .contentShape(Rectangle())
            .onTapGesture {
              isSeedPhraseRevealed = true
            }
          } else {
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
            .privacySensitive()
          }
        }
        .padding(.vertical, 8)
      } else {
        ProgressView()
          .padding()
      }
      
      if isSeedPhraseRevealed && !isAppInBackground {
        Button(action: {
          showCopyWarning = true
        }) {
          HStack {
            Image(systemName: "doc.on.doc")
            Text("Copy Seed Phrase")
          }
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.blue)
        }
      }
      
      if isSeedPhraseRevealed && !isAppInBackground {
        VStack(spacing: 8) {
          Toggle("I have written down my seed phrase", isOn: $confirmedBackup)
            .font(.system(size: 16))
          
          Text("Make sure you've written it down correctly. You won't be able to see it again after this step.")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
      }
      
      if isSeedPhraseRevealed && !isAppInBackground {
        Button(action: {
          if confirmedBackup {
            dismiss()
          }
        }) {
          Text("Done")
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
