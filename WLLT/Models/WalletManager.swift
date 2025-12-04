import Combine
import Foundation
import KeychainAccess
import web3swift

class WalletManager: ObservableObject {
  static let shared = WalletManager()
    
  @Published var hasWallet: Bool = false
  @Published var walletAddress: String?
  @Published var balances: [NetworkBalance] = []
  @Published var tokens: [Token] = []
  @Published var transactions: [Transaction] = []
    
  private let keychain = Keychain(service: "com.wllt.wallet")
  private let seedPhraseKey = "wallet_seed_phrase"
    
  private init() {
    checkWalletExists()
  }
    
  func checkWalletExists() {
    hasWallet = keychain[seedPhraseKey] != nil
    if hasWallet {
      loadWallet()
    }
  }
    
  func createWallet() throws -> String {
    let mnemonic = try BIP39.generateMnemonics(bitsOfEntropy: 128)
    guard let mnemonic else {
      throw WalletError.mnemonicGenerationFailed
    }
        
    try saveSeedPhrase(mnemonic)
    try loadWalletFromSeed(mnemonic)
        
    return mnemonic
  }
    
  func importWallet(seedPhrase: String) throws {
    guard BIP39.mnemonicsToEntropy(seedPhrase) != nil else {
      throw WalletError.invalidSeedPhrase
    }
        
    try saveSeedPhrase(seedPhrase)
    try loadWalletFromSeed(seedPhrase)
  }
    
  func deleteWallet() throws {
    try keychain.remove(seedPhraseKey)
    hasWallet = false
    walletAddress = nil
    balances = []
    tokens = []
    transactions = []
  }
    
  func getSeedPhrase() throws -> String {
    guard let seedPhrase = keychain[seedPhraseKey] else {
      throw WalletError.walletNotFound
    }
    return seedPhrase
  }
    
  private func saveSeedPhrase(_ seedPhrase: String) throws {
    try keychain.set(seedPhrase, key: seedPhraseKey)
    hasWallet = true
  }
    
  private func loadWallet() {
    guard let seedPhrase = keychain[seedPhraseKey] else {
      return
    }
        
    do {
      try loadWalletFromSeed(seedPhrase)
    } catch {
      print("Failed to load wallet: \(error)")
    }
  }
    
  private func loadWalletFromSeed(_ seedPhrase: String) throws {
    guard let keystore = try? BIP32Keystore(
      mnemonics: seedPhrase,
      password: "",
      mnemonicsPassword: ""
    ),
      let keystore,
      let address = keystore.addresses?.first?.address
    else {
      throw WalletError.walletCreationFailed
    }
        
    walletAddress = address
    Task {
      await loadBalances()
      await loadTokens()
      await loadTransactions()
    }
  }
    
  @MainActor
  func loadBalances() async {
    guard let address = walletAddress else { return }
        
    var newBalances: [NetworkBalance] = []
        
    for network in SupportedNetwork.allCases {
      if let balance = await fetchBalance(address: address, network: network) {
        newBalances.append(balance)
      }
    }
        
    balances = newBalances
  }
    
  @MainActor
  func loadTokens() async {
    guard let address = walletAddress else { return }
        
    var newTokens: [Token] = []
        
    for network in SupportedNetwork.allCases {
      let networkTokens = await fetchTokens(address: address, network: network)
      newTokens.append(contentsOf: networkTokens)
    }
        
    tokens = newTokens
  }
    
  @MainActor
  func loadTransactions() async {
    guard let address = walletAddress else { return }
        
    var allTransactions: [Transaction] = []
        
    for network in SupportedNetwork.allCases {
      let networkTransactions = await fetchTransactions(address: address, network: network)
      allTransactions.append(contentsOf: networkTransactions)
    }
        
    transactions = allTransactions.sorted { $0.timestamp > $1.timestamp }
  }
    
  func sendTransaction(
    to: String,
    amount: String,
    network: SupportedNetwork,
    tokenAddress: String? = nil
  ) async throws -> String {
    guard let seedPhrase = keychain[seedPhraseKey] else {
      throw WalletError.walletNotFound
    }
        
    guard let keystore = try? BIP32Keystore(
      mnemonics: seedPhrase,
      password: "",
      mnemonicsPassword: ""
    ),
      let keystore,
      let address = keystore.addresses?.first
    else {
      throw WalletError.walletCreationFailed
    }
        
    let web3 = try await getWeb3(network: network)
    let gasPrice = try await web3.eth.getGasPrice()
    let gasLimit = BigUInt(21000)
        
    var transaction: EthereumTransaction
        
    if let tokenAddress {
      transaction = try await createTokenTransferTransaction(
        web3: web3,
        from: address,
        to: to,
        amount: amount,
        tokenAddress: tokenAddress
      )
    } else {
      guard let toAddress = EthereumAddress(to) else {
        throw WalletError.invalidAddress
      }
      let value = try parseAmount(amount)
      transaction = EthereumTransaction(
        gasPrice: gasPrice,
        gasLimit: gasLimit,
        to: toAddress,
        value: value,
        data: Data()
      )
    }
        
    try Web3Signer.signTX(transaction: &transaction, keystore: keystore, account: address, password: "")
        
    let result = try await web3.eth.sendRawTransaction(transaction)
        
    await loadBalances()
    await loadTransactions()
        
    return result.hash
  }
    
  private func fetchBalance(address: String, network: SupportedNetwork) async -> NetworkBalance? {
    do {
      guard let ethAddress = EthereumAddress(address) else {
        return nil
      }
      let web3 = try await getWeb3(network: network)
      let balance = try await web3.eth.getBalance(address: ethAddress)
      let balanceString = Web3.Utils.formatToEthereumUnits(balance, toUnits: .eth, decimals: 6) ?? "0"
            
      return NetworkBalance(
        network: network,
        balance: balanceString,
        symbol: network.nativeSymbol
      )
    } catch {
      return nil
    }
  }
    
  private func fetchTokens(address: String, network: SupportedNetwork) async -> [Token] {
    do {
      let apiKey = ExplorerAPI.getAPIKey(for: network) ?? ""
      let apiKeyParam = apiKey.isEmpty ? "" : "&apikey=\(apiKey)"
      let urlString =
        "\(network.explorerAPIUrl)?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc\(apiKeyParam)"
            
      guard let url = URL(string: urlString) else {
        return []
      }
            
      let (data, _) = try await URLSession.shared.data(from: url)
      let response = try JSONDecoder().decode(EtherscanTokenResponse.self, from: data)
            
      guard response.status == "1" else {
        return []
      }
            
      var tokenMap: [String: (name: String, symbol: String, decimals: Int, balance: Decimal)] = [:]
            
      let addressLower = address.lowercased()
            
      for tokenTx in response.result {
        guard let decimals = Int(tokenTx.tokenDecimal),
              let valueWei = Decimal(string: tokenTx.value)
        else {
          continue
        }
                
        let divisor = Decimal(pow(10.0, Double(decimals)))
        let value = valueWei / divisor
                
        let contractAddress = tokenTx.contractAddress.lowercased()
                
        if tokenTx.from.lowercased() == addressLower {
          if let existing = tokenMap[contractAddress] {
            tokenMap[contractAddress] = (
              name: existing.name,
              symbol: existing.symbol,
              decimals: existing.decimals,
              balance: max(0, existing.balance - value)
            )
          }
        } else if tokenTx.to.lowercased() == addressLower {
          if let existing = tokenMap[contractAddress] {
            tokenMap[contractAddress] = (
              name: existing.name,
              symbol: existing.symbol,
              decimals: existing.decimals,
              balance: existing.balance + value
            )
          } else {
            tokenMap[contractAddress] = (
              name: tokenTx.tokenName,
              symbol: tokenTx.tokenSymbol,
              decimals: decimals,
              balance: value
            )
          }
        }
      }
            
      return tokenMap.compactMap { address, info -> Token? in
        guard info.balance > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        let balanceString = formatter.string(from: info.balance as NSDecimalNumber) ?? "0"
                
        return Token(
          address: address,
          name: info.name,
          symbol: info.symbol,
          balance: balanceString,
          decimals: info.decimals,
          network: network
        )
      }
    } catch {
      return []
    }
  }
    
  private func fetchTransactions(address: String, network: SupportedNetwork) async -> [Transaction] {
    do {
      let apiKey = ExplorerAPI.getAPIKey(for: network) ?? ""
      let apiKeyParam = apiKey.isEmpty ? "" : "&apikey=\(apiKey)"
      let urlString =
        "\(network.explorerAPIUrl)?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc\(apiKeyParam)"
            
      guard let url = URL(string: urlString) else {
        return []
      }
            
      let (data, _) = try await URLSession.shared.data(from: url)
      let response = try JSONDecoder().decode(EtherscanResponse.self, from: data)
            
      guard response.status == "1" else {
        return []
      }
            
      return response.result.compactMap { tx -> Transaction? in
        guard let timestamp = Double(tx.timeStamp),
              tx.isError != "1"
        else {
          return nil
        }
                
        let date = Date(timeIntervalSince1970: timestamp)
        let isSent = tx.from.lowercased() == address.lowercased()
                
        let amount: String
        let symbol: String
                
        if let contractAddress = tx.contractAddress, !contractAddress.isEmpty {
          let decimals = Int(tx.tokenDecimal ?? "18") ?? 18
          amount = formatTokenAmount(tx.value, decimals: decimals)
          symbol = tx.tokenSymbol ?? "TOKEN"
        } else {
          amount = formatAmount(tx.value)
          symbol = network.nativeSymbol
        }
                
        return Transaction(
          hash: tx.hash,
          from: tx.from,
          to: tx.to,
          amount: amount,
          symbol: symbol,
          timestamp: date,
          network: network,
          type: isSent ? .sent : .received
        )
      }
    } catch {
      return []
    }
  }
    
  private func formatAmount(_ wei: String) -> String {
    guard let weiDecimal = Decimal(string: wei) else {
      return "0"
    }
    let eth = weiDecimal / 1_000_000_000_000_000_000
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 6
    formatter.minimumFractionDigits = 0
    return formatter.string(from: eth as NSDecimalNumber) ?? "0"
  }
    
  private func formatTokenAmount(_ amount: String, decimals: Int) -> String {
    guard let amountDecimal = Decimal(string: amount) else {
      return "0"
    }
    let divisor = pow(10.0, decimals)
    let tokenAmount = amountDecimal / divisor
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 6
    formatter.minimumFractionDigits = 0
    return formatter.string(from: tokenAmount as NSDecimalNumber) ?? "0"
  }
    
  private func getWeb3(network: SupportedNetwork) async throws -> web3 {
    guard let url = URL(string: network.rpcUrl) else {
      throw WalletError.invalidRPCUrl
    }
    return try await Web3.new(url)
  }
    
  private func parseAmount(_ amount: String) throws -> BigUInt {
    guard let amountDecimal = Decimal(string: amount) else {
      throw WalletError.invalidAmount
    }
    return try Web3.Utils.parseToBigUInt(amount, units: .eth)
  }
    
  private func createTokenTransferTransaction(
    web3: web3,
    from _: EthereumAddress,
    to: String,
    amount: String,
    tokenAddress: String
  ) async throws -> EthereumTransaction {
    guard let tokenEthAddress = EthereumAddress(tokenAddress),
          let toEthAddress = EthereumAddress(to)
    else {
      throw WalletError.invalidAddress
    }
        
    let contract = web3.contract(Web3.Utils.erc20ABI, at: tokenEthAddress)
    let amountBigUInt = try parseTokenAmount(amount, decimals: 18)
        
    let transaction = contract?.method(
      "transfer",
      parameters: [toEthAddress, amountBigUInt] as [AnyObject],
      extraData: Data(),
      transactionOptions: nil
    )
        
    guard let tx = transaction else {
      throw WalletError.transactionCreationFailed
    }
        
    return tx.transaction
  }
    
  private func parseTokenAmount(_ amount: String, decimals: Int) throws -> BigUInt {
    guard let amountDecimal = Decimal(string: amount) else {
      throw WalletError.invalidAmount
    }
    let multiplier = pow(10.0, decimals)
    let amountInWei = amountDecimal * multiplier
    return BigUInt(amountInWei.description) ?? 0
  }
}

enum WalletError: LocalizedError {
  case mnemonicGenerationFailed
  case invalidSeedPhrase
  case walletNotFound
  case walletCreationFailed
  case invalidAmount
  case transactionCreationFailed
  case invalidAddress
  case invalidRPCUrl
    
  var errorDescription: String? {
    switch self {
    case .mnemonicGenerationFailed:
      "Failed to generate seed phrase"
    case .invalidSeedPhrase:
      "Invalid seed phrase"
    case .walletNotFound:
      "Wallet not found"
    case .walletCreationFailed:
      "Failed to create wallet"
    case .invalidAmount:
      "Invalid amount"
    case .transactionCreationFailed:
      "Failed to create transaction"
    case .invalidAddress:
      "Invalid Ethereum address"
    case .invalidRPCUrl:
      "Invalid RPC URL"
    }
  }
}
