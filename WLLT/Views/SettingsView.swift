import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showSeedPhrase = false
    @State private var showDeleteWallet = false
    @State private var requireConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if let address = walletManager.walletAddress {
                        HStack {
                            Text("Address")
                            Spacer()
                            Text(address.prefix(10) + "..." + address.suffix(6))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Network") {
                    Picker("Network Mode", selection: $walletManager.networkMode) {
                        ForEach(NetworkMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    
                    if walletManager.networkMode == .testnet {
                        TestTokensSection()
                            .environmentObject(walletManager)
                    }
                }
                
                Section("Security") {
                    Button(action: {
                        requireConfirmation = true
                    }) {
                        HStack {
                            Text("Show Seed Phrase")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Danger Zone") {
                    Button(role: .destructive, action: {
                        showDeleteWallet = true
                    }) {
                        Text("Delete Wallet")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Show Seed Phrase", isPresented: $requireConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Show") {
                    showSeedPhrase = true
                }
            } message: {
                Text("Are you sure you want to view your seed phrase? Make sure no one can see your screen.")
            }
            .sheet(isPresented: $showSeedPhrase) {
                SeedPhraseView()
            }
            .alert("Delete Wallet", isPresented: $showDeleteWallet) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteWallet()
                }
            } message: {
                Text("This will permanently delete your wallet from this device. Make sure you have your seed phrase backed up.")
            }
        }
    }
    
    private func deleteWallet() {
        do {
            try walletManager.deleteWallet()
            authManager.logout()
        } catch {
            print("Failed to delete wallet: \(error)")
        }
    }
}

struct SeedPhraseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @State private var seedPhrase: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Your Seed Phrase")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Never share your seed phrase with anyone. Anyone with access to it can control your wallet.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if !seedPhrase.isEmpty {
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
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Seed Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSeedPhrase()
            }
        }
    }
    
    private func loadSeedPhrase() {
        do {
            seedPhrase = try walletManager.getSeedPhrase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct TestTokensSection: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var selectedNetwork: SupportedNetwork = .sepolia
    
    var availableNetworks: [SupportedNetwork] {
        SupportedNetwork.all(for: .testnet)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Get Test Tokens")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Picker("Network", selection: $selectedNetwork) {
                ForEach(availableNetworks, id: \.self) { network in
                    Text(network.name).tag(network)
                }
            }
            .pickerStyle(.menu)
            
            if let faucetURL = walletManager.getFaucetURL(for: selectedNetwork) {
                Link(destination: faucetURL) {
                    HStack {
                        Image(systemName: "drop.fill")
                        Text("Open Faucet")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("Your address will be pre-filled. Follow the instructions on the faucet page to receive test tokens.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .onAppear {
            if let firstNetwork = availableNetworks.first {
                selectedNetwork = firstNetwork
            }
        }
    }
}
