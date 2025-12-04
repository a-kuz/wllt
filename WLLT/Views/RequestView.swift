import SwiftUI
import web3swift

struct RequestView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var walletManager: WalletManager
  @StateObject private var wcManager = WalletConnectManager.shared
  let request: WCRequest
  
  @State private var isProcessing = false
  @State private var errorMessage: String?
  @State private var showConfirmation = false
  
  var body: some View {
    NavigationView {
      Form {
        Section("dApp") {
          if let session = wcManager.sessions.first(where: { $0.topic == request.request.topic }) {
            Text(session.peer.name)
              .font(.system(size: 16, weight: .medium))
            Text(session.peer.url)
              .font(.system(size: 14))
              .foregroundColor(.secondary)
          }
        }
        
        Section("Request") {
          Text(requestMethod)
            .font(.system(size: 16, weight: .medium))
          Text(requestDetails)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        
        if let error = errorMessage {
          Section {
            Text(error)
              .foregroundColor(.red)
              .font(.system(size: 14))
          }
        }
      }
      .navigationTitle("Approve Request")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Reject") {
            rejectRequest()
          }
          .foregroundColor(.red)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Approve") {
            showConfirmation = true
          }
          .disabled(isProcessing)
        }
      }
      .alert("Confirm", isPresented: $showConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Approve") {
          approveRequest()
        }
      } message: {
        Text("Do you want to approve this request?")
      }
    }
  }
  
  private var requestMethod: String {
    request.request.method
  }
  
  private var requestDetails: String {
    if let params = request.request.params as? [String: Any] {
      if let jsonData = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        return jsonString
      }
    }
    return "No details available"
  }
  
  private func approveRequest() {
    isProcessing = true
    errorMessage = nil
    
    Task {
      do {
        let result = try await processRequest()
        try await wcManager.approveRequest(request, result: AnyCodable(result))
        
        await MainActor.run {
          isProcessing = false
          dismiss()
        }
      } catch {
        await MainActor.run {
          isProcessing = false
          errorMessage = error.localizedDescription
        }
      }
    }
  }
  
  private func rejectRequest() {
    Task {
      do {
        try await wcManager.rejectRequest(request)
        await MainActor.run {
          dismiss()
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
        }
      }
    }
  }
  
  private func processRequest() async throws -> Any {
    guard let seedPhrase = try? walletManager.getSeedPhrase() else {
      throw WalletConnectError.clientNotInitialized
    }
    
    guard let keystore = try? BIP32Keystore(
      mnemonics: seedPhrase,
      password: "",
      mnemonicsPassword: ""
    ),
      let keystore,
      let address = keystore.addresses?.first
    else {
      throw WalletConnectError.clientNotInitialized
    }
    
    switch request.request.method {
    case "eth_sendTransaction":
      return try await handleSendTransaction(request: request.request, keystore: keystore, account: address)
      
    case "eth_signTransaction":
      return try await handleSignTransaction(request: request.request, keystore: keystore, account: address)
      
    case "personal_sign", "eth_sign":
      return try handleSignMessage(request: request.request, keystore: keystore, account: address)
      
    case "eth_accounts":
      return [address.address]
      
    default:
      throw WalletConnectError.invalidMessage
    }
  }
  
  private func handleSendTransaction(request: Request, keystore: BIP32Keystore, account: EthereumAddress) async throws -> String {
    guard let params = request.params as? [[String: Any]],
          let txParams = params.first,
          let to = txParams["to"] as? String,
          let toAddress = EthereumAddress(to) else {
      throw WalletConnectError.invalidMessage
    }
    
    let value = txParams["value"] as? String ?? "0x0"
    let gasPrice = txParams["gasPrice"] as? String ?? "0x0"
    let gasLimit = txParams["gas"] as? String ?? "0x21000"
    let chainIdHex = txParams["chainId"] as? String ?? "0x1"
    
    let chainId = UInt64(chainIdHex.dropFirst(2), radix: 16) ?? 1
    let network = SupportedNetwork.from(chainId: chainId) ?? .ethereum
    let web3 = try await walletManager.getWeb3(network: network)
    
    let valueBigUInt = BigUInt(value.dropFirst(2), radix: 16) ?? 0
    let gasPriceBigUInt = BigUInt(gasPrice.dropFirst(2), radix: 16) ?? 0
    let gasLimitBigUInt = BigUInt(gasLimit.dropFirst(2), radix: 16) ?? 21000
    
    var transaction = EthereumTransaction(
      gasPrice: gasPriceBigUInt,
      gasLimit: gasLimitBigUInt,
      to: toAddress,
      value: valueBigUInt,
      data: Data()
    )
    
    try Web3Signer.signTX(transaction: &transaction, keystore: keystore, account: account, password: "")
    
    let result = try await web3.eth.sendRawTransaction(transaction)
    
    await walletManager.loadBalances()
    await walletManager.loadTransactions()
    
    return result.hash
  }
  
  private func handleSignTransaction(request: Request, keystore: BIP32Keystore, account: EthereumAddress) async throws -> String {
    guard let params = request.params as? [[String: Any]],
          let txParams = params.first,
          let to = txParams["to"] as? String,
          let toAddress = EthereumAddress(to) else {
      throw WalletConnectError.invalidMessage
    }
    
    let value = txParams["value"] as? String ?? "0x0"
    let gasPrice = txParams["gasPrice"] as? String ?? "0x0"
    let gasLimit = txParams["gas"] as? String ?? "0x21000"
    let chainIdHex = txParams["chainId"] as? String ?? "0x1"
    
    let valueBigUInt = BigUInt(value.dropFirst(2), radix: 16) ?? 0
    let gasPriceBigUInt = BigUInt(gasPrice.dropFirst(2), radix: 16) ?? 0
    let gasLimitBigUInt = BigUInt(gasLimit.dropFirst(2), radix: 16) ?? 21000
    
    var transaction = EthereumTransaction(
      gasPrice: gasPriceBigUInt,
      gasLimit: gasLimitBigUInt,
      to: toAddress,
      value: valueBigUInt,
      data: Data()
    )
    
    try Web3Signer.signTX(transaction: &transaction, keystore: keystore, account: account, password: "")
    
    let signedTxData = try transaction.encode() ?? Data()
    return "0x" + signedTxData.map { String(format: "%02x", $0) }.joined()
  }
  
  private func handleSignMessage(request: Request, keystore: BIP32Keystore, account: EthereumAddress) throws -> String {
    guard let params = request.params as? [Any],
          params.count >= 2,
          let messageHex = params[0] as? String else {
      throw WalletConnectError.invalidMessage
    }
    
    let messageHexCleaned = messageHex.hasPrefix("0x") ? String(messageHex.dropFirst(2)) : messageHex
    guard let messageData = Data(hex: messageHexCleaned) else {
      throw WalletConnectError.invalidMessage
    }
    
    let messageString = String(data: messageData, encoding: .utf8) ?? messageHex
    
    let prefix = "\u{19}Ethereum Signed Message:\n\(messageData.count)"
    guard let prefixData = prefix.data(using: .utf8) else {
      throw WalletConnectError.invalidMessage
    }
    
    let hash = (prefixData + messageData).sha3(.keccak256)
    
    guard let signature = try? Web3Signer.signPersonalMessage(hash, keystore: keystore, account: account, password: "") else {
      throw WalletConnectError.signingFailed
    }
    
    return "0x" + signature.map { String(format: "%02x", $0) }.joined()
  }
}

extension WalletManager {
  func getWeb3(network: SupportedNetwork) async throws -> Web3 {
    guard let url = URL(string: network.rpcUrl) else {
      throw WalletError.invalidRPCUrl
    }
    return try await Web3.new(url)
  }
}
