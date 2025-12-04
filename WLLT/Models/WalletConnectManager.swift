import Combine
import Foundation
import web3swift

class WalletConnectManager: ObservableObject {
  static let shared = WalletConnectManager()
  
  @Published var sessions: [Any] = []
  @Published var pendingRequests: [WCRequest] = []
  @Published var isConnected: Bool = false
  
  private init() {
  }
  
  private func setupWalletConnect() {
    let projectIdString = "67ca74718ec771a4e4200d55c7fcd33c"
    
    let formattedProjectId: String
    if projectIdString.count == 32 {
      let start = projectIdString.startIndex
      let index1 = projectIdString.index(start, offsetBy: 8)
      let index2 = projectIdString.index(index1, offsetBy: 4)
      let index3 = projectIdString.index(index2, offsetBy: 4)
      let index4 = projectIdString.index(index3, offsetBy: 4)
      formattedProjectId = "\(projectIdString[..<index1])-\(projectIdString[index1..<index2])-\(projectIdString[index2..<index3])-\(projectIdString[index3..<index4])-\(projectIdString[index4...])"
    } else {
      formattedProjectId = projectIdString
    }
    
    guard let projectIdUUID = UUID(uuidString: formattedProjectId) else {
      print("Invalid WalletConnect Project ID")
      return
    }
    
  }
  
  func connect(uri: String) async throws {
    throw WalletConnectError.clientNotInitialized
  }
  
  func disconnect(sessionTopic: String) async throws {
  }
  
  func loadSessions() {
  }
  
  func approveRequest(_ request: WCRequest, result: Any) async throws {
    throw WalletConnectError.clientNotInitialized
  }
  
  func rejectRequest(_ request: WCRequest) async throws {
  }
  
  func signTransaction(request: WCRequest, transaction: EthereumTransaction, keystore: BIP32Keystore, account: EthereumAddress) async throws -> String {
    var tx = transaction
    try Web3Signer.signTX(transaction: &tx, keystore: keystore, account: account, password: "")
    
    let signedTxData = try tx.encode() ?? Data()
    let hexString = "0x" + signedTxData.map { String(format: "%02x", $0) }.joined()
    
    return hexString
  }
  
  func signMessage(request: WCRequest, message: String, keystore: BIP32Keystore, account: EthereumAddress) throws -> String {
    guard let messageData = message.data(using: .utf8) else {
      throw WalletConnectError.invalidMessage
    }
    
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

enum WalletConnectError: LocalizedError {
  case invalidURI
  case clientNotInitialized
  case invalidMessage
  case signingFailed
  
  var errorDescription: String? {
    switch self {
    case .invalidURI:
      "Invalid WalletConnect URI"
    case .clientNotInitialized:
      "WalletConnect client not initialized"
    case .invalidMessage:
      "Invalid message format"
    case .signingFailed:
      "Failed to sign message"
    }
  }
}

struct WCRequest: Identifiable {
  let id: UUID
  let request: Any
  
  init(request: Any) {
    self.id = UUID()
    self.request = request
  }
}

extension Data {
  func sha3(_ variant: SHA3.Variant) -> Data {
    return SHA3(variant: variant).calculate(for: self.bytes)
  }
}
