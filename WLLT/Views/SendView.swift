import SwiftUI

struct SendView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var walletManager: WalletManager
  @State private var recipientAddress: String = ""
  @State private var amount: String = ""
  @State private var selectedNetwork: SupportedNetwork = .ethereum
  @State private var selectedToken: Token?
  @State private var isSending = false
  @State private var errorMessage: String?
  @State private var showConfirmation = false
    
  var body: some View {
    NavigationView {
      Form {
        Section("Network") {
          Picker("Network", selection: $selectedNetwork) {
            ForEach(SupportedNetwork.allCases, id: \.self) { network in
              Text(network.name).tag(network)
            }
          }
        }
                
        Section("Recipient") {
          TextField("Address", text: $recipientAddress)
            .font(.system(.body, design: .monospaced))
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
                
        Section("Token") {
          Picker("Token", selection: $selectedToken) {
            Text("Native (\(selectedNetwork.nativeSymbol))").tag(nil as Token?)
            ForEach(walletManager.tokens.filter { $0.network == selectedNetwork }) { token in
              Text("\(token.symbol) - \(token.name)").tag(token as Token?)
            }
          }
        }
                
        Section("Amount") {
          TextField("0.0", text: $amount)
            .keyboardType(.decimalPad)
                    
          if let token = selectedToken {
            HStack {
              Text("Available:")
              Spacer()
              Text("\(token.balance) \(token.symbol)")
                .foregroundColor(.secondary)
            }
            .font(.system(size: 14))
          } else if let balance = walletManager.balances.first(where: { $0.network == selectedNetwork }) {
            HStack {
              Text("Available:")
              Spacer()
              Text("\(balance.balance) \(balance.symbol)")
                .foregroundColor(.secondary)
            }
            .font(.system(size: 14))
          }
        }
                
        if let error = errorMessage {
          Section {
            Text(error)
              .foregroundColor(.red)
              .font(.system(size: 14))
          }
        }
      }
      .navigationTitle("Send")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
                
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Send") {
            validateAndSend()
          }
          .disabled(isSending || recipientAddress.isEmpty || amount.isEmpty)
        }
      }
      .alert("Confirm Transaction", isPresented: $showConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Confirm") {
          sendTransaction()
        }
      } message: {
        let symbol = selectedToken?.symbol ?? selectedNetwork.nativeSymbol
        Text("Send \(amount) \(symbol) to \(recipientAddress.prefix(10))...\(recipientAddress.suffix(6))?")
      }
    }
  }
    
  private func validateAndSend() {
    guard !recipientAddress.isEmpty,
          !amount.isEmpty,
          Double(amount) != nil
    else {
      errorMessage = "Please enter valid address and amount"
      return
    }
        
    guard isValidEthereumAddress(recipientAddress) else {
      errorMessage = "Invalid Ethereum address"
      return
    }
        
    guard let amountValue = Double(amount), amountValue > 0 else {
      errorMessage = "Amount must be greater than 0"
      return
    }
        
    if let token = selectedToken {
      if let tokenBalanceValue = Double(token.balance),
         amountValue > tokenBalanceValue {
        errorMessage = "Insufficient balance. Available: \(token.balance) \(token.symbol)"
        return
      }
    } else if let balance = walletManager.balances.first(where: { $0.network == selectedNetwork }),
              let balanceValue = Double(balance.balance),
              amountValue > balanceValue {
      errorMessage = "Insufficient balance. Available: \(balance.balance) \(balance.symbol)"
      return
    }
        
    showConfirmation = true
  }
    
  private func isValidEthereumAddress(_ address: String) -> Bool {
    let addressRegex = "^0x[a-fA-F0-9]{40}$"
    let predicate = NSPredicate(format: "SELF MATCHES %@", addressRegex)
    return predicate.evaluate(with: address)
  }

  private func sendTransaction() {
    isSending = true
    errorMessage = nil
        
    Task {
      do {
        let txHash = try await walletManager.sendTransaction(
          to: recipientAddress,
          amount: amount,
          network: selectedNetwork,
          tokenAddress: selectedToken?.address
        )
                
        await MainActor.run {
          isSending = false
          dismiss()
        }
      } catch {
        await MainActor.run {
          isSending = false
          errorMessage = error.localizedDescription
        }
      }
    }
  }
}
