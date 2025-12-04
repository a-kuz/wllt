import Combine
import Foundation
import BigInt
import KeychainAccess
import Web3Core
import web3swift

class WalletManager: ObservableObject {
  static let shared = WalletManager()
    
  @Published var hasWallet: Bool = false
  @Published var walletAddress: String?
  @Published var balances: [NetworkBalance] = []
  @Published var tokens: [Token] = []
  @Published var transactions: [Transaction] = []
  @Published var networkMode: NetworkMode = .mainnet {
    didSet {
      UserDefaults.standard.set(networkMode.rawValue, forKey: "network_mode")
      Task {
        await loadBalances()
        await loadTokens()
        await loadTransactions()
      }
    }
  }
    
  private let keychain = Keychain(service: "com.wllt.wallet")
  private let seedPhraseKey = "wallet_seed_phrase"
  private let networkModeKey = "network_mode"
    
  private init() {
    if let savedMode = UserDefaults.standard.string(forKey: networkModeKey),
       let mode = NetworkMode(rawValue: savedMode) {
      networkMode = mode
    }
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
        
    for network in SupportedNetwork.all(for: networkMode) {
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
        
    for network in SupportedNetwork.all(for: networkMode) {
      let networkTokens = await fetchTokens(address: address, network: network)
      newTokens.append(contentsOf: networkTokens)
    }
        
    tokens = newTokens
  }
    
  @MainActor
  func loadTransactions() async {
    guard let address = walletAddress else { return }
        
    var allTransactions: [Transaction] = []
        
    for network in SupportedNetwork.all(for: networkMode) {
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
      let address = keystore.addresses?.first
    else {
      throw WalletError.walletCreationFailed
    }
        
    let web3 = try await getWeb3(network: network)
    let gasPrice = try await web3.eth.gasPrice()
    let gasLimit = BigUInt(21000)
        
    var transaction: CodableTransaction
        
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
      transaction = CodableTransaction.emptyTransaction
      transaction.to = toAddress
      transaction.value = value
      transaction.gasLimit = gasLimit
      transaction.gasPrice = gasPrice
      transaction.from = address
    }
        
    web3.addKeystoreManager(KeystoreManager([keystore]))
    let result = try await web3.eth.send(transaction)
        
    await loadBalances()
    await loadTransactions()
        
    return result.hash
  }
  
  private func createTokenTransferTransaction(
    web3: Web3,
    from: EthereumAddress,
    to: String,
    amount: String,
    tokenAddress: String
  ) async throws -> CodableTransaction {
    guard let tokenEthAddress = EthereumAddress(tokenAddress),
          let toEthAddress = EthereumAddress(to)
    else {
      throw WalletError.invalidAddress
    }
        
    guard let contract = web3.contract(Web3.Utils.erc20ABI, at: tokenEthAddress) else {
      throw WalletError.transactionCreationFailed
    }
    let amountBigUInt = try parseTokenAmount(amount, decimals: 18)
    
    var transaction = CodableTransaction.emptyTransaction
    transaction.from = from
    transaction.to = tokenEthAddress
    contract.transaction = transaction
    
    guard let writeOp = contract.createWriteOperation(
      "transfer",
      parameters: [toEthAddress, amountBigUInt] as [Any]
    ) else {
      throw WalletError.transactionCreationFailed
    }
    
    return writeOp.transaction
  }
    
  private func fetchBalance(address: String, network: SupportedNetwork) async -> NetworkBalance? {
    guard let ethAddress = EthereumAddress(address) else {
      return nil
    }
    
    do {
      let web3 = try await getWeb3(network: network)
      let balance = try await web3.eth.getBalance(for: ethAddress)
      guard let balanceDecimal = Decimal(string: balance.description) else {
        return NetworkBalance(
          network: network,
          balance: "0",
          symbol: network.nativeSymbol
        )
      }
      let weiPerEth = Decimal(1_000_000_000_000_000_000)
      let ethBalance = balanceDecimal / weiPerEth
      let formatter = NumberFormatter()
      formatter.numberStyle = .decimal
      formatter.maximumFractionDigits = 8
      formatter.minimumFractionDigits = 0
      formatter.usesGroupingSeparator = false
      let balanceString = formatter.string(from: ethBalance as NSDecimalNumber) ?? "0"
            
      return NetworkBalance(
        network: network,
        balance: balanceString,
        symbol: network.nativeSymbol
      )
    } catch {
      return NetworkBalance(
        network: network,
        balance: "0",
        symbol: network.nativeSymbol
      )
    }
  }
    
  private func fetchTokens(address: String, network: SupportedNetwork) async -> [Token] {
    let urls = getTokenAPIUrls(address: address, network: network)
    
    for urlString in urls {
      guard let url = URL(string: urlString) else {
        continue
      }
      
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
          let decoder = JSONDecoder()
          let apiResponse = try decoder.decode(EtherscanTokenResponse.self, from: data)
          
          guard apiResponse.status == "1" else {
            continue
          }
          
          var tokenMap: [String: (name: String, symbol: String, decimals: Int, balance: Decimal)] = [:]
                  
          let addressLower = address.lowercased()
                  
          for tokenTx in apiResponse.result {
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
        }
      } catch {
        continue
      }
    }
    
    return []
  }
  
  private func getTokenAPIUrls(address: String, network: SupportedNetwork) -> [String] {
    let apiKey = ExplorerAPI.getAPIKey(for: network) ?? ""
    let apiKeyParam = apiKey.isEmpty ? "" : "&apikey=\(apiKey)"
    let chainId = network.chainId
    
    var urls: [String] = []
    
    switch network {
    case .ethereum:
      urls.append("https://api.etherscan.io/v2/api?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc&chainid=\(chainId)\(apiKeyParam)")
      urls.append("https://eth.blockscout.com/api?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc")
    case .sepolia:
      urls.append("https://api-sepolia.etherscan.io/v2/api?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc&chainid=\(chainId)\(apiKeyParam)")
      urls.append("https://sepolia.blockscout.com/api?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc")
    case .polygon:
      urls.append("https://api.polygonscan.com/v2/api?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc&chainid=\(chainId)\(apiKeyParam)")
      urls.append("https://polygon.blockscout.com/api?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc")
    case .mumbai:
      urls.append("https://api-testnet.polygonscan.com/v2/api?module=account&action=tokentx&address=\(address)&startblock=0&endblock=99999999&sort=desc&chainid=\(chainId)\(apiKeyParam)")
    }
    
    return urls
  }
    
  private func fetchTransactions(address: String, network: SupportedNetwork) async -> [Transaction] {
    let urls = getTransactionAPIUrls(address: address, network: network)
    
    for urlString in urls {
      guard let url = URL(string: urlString) else {
        continue
      }
      
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200 {
          let decoder = JSONDecoder()
          let apiResponse = try decoder.decode(EtherscanResponse.self, from: data)
          
          guard apiResponse.status == "1" else {
            continue
          }
          
          return apiResponse.result.compactMap { tx -> Transaction? in
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
        }
      } catch {
        continue
      }
    }
    
    return []
  }
  
  private func getTransactionAPIUrls(address: String, network: SupportedNetwork) -> [String] {
    let apiKey = ExplorerAPI.getAPIKey(for: network) ?? ""
    let apiKeyParam = apiKey.isEmpty ? "" : "&apikey=\(apiKey)"
    let chainId = network.chainId
    
    var urls: [String] = []
    
    switch network {
    case .ethereum:
      urls.append("https://api.etherscan.io/v2/api?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc&chainid=\(chainId)\(apiKeyParam)")
      urls.append("https://eth.blockscout.com/api?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc")
    case .sepolia:
      urls.append("https://api-sepolia.etherscan.io/v2/api?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc&chainid=\(chainId)\(apiKeyParam)")
      urls.append("https://sepolia.blockscout.com/api?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc")
    case .polygon:
      urls.append("https://api.polygonscan.com/v2/api?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc&chainid=\(chainId)\(apiKeyParam)")
      urls.append("https://polygon.blockscout.com/api?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc")
    case .mumbai:
      urls.append("https://api-testnet.polygonscan.com/v2/api?module=account&action=txlist&address=\(address)&startblock=0&endblock=99999999&page=1&offset=50&sort=desc&chainid=\(chainId)\(apiKeyParam)")
    }
    
    return urls
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
    
  private func getWeb3(network: SupportedNetwork) async throws -> Web3 {
    let rpcUrls = getRpcUrls(for: network)
    
    for rpcUrl in rpcUrls {
      guard let url = URL(string: rpcUrl) else {
        continue
      }
      do {
        return try await Web3.new(url)
      } catch {
        continue
      }
    }
    
    throw WalletError.invalidRPCUrl
  }
  
  private func getRpcUrls(for network: SupportedNetwork) -> [String] {
    switch network {
    case .ethereum:
      return [
        "https://ethereum.publicnode.com",
        "https://rpc.ankr.com/eth",
        "https://eth.llamarpc.com"
      ]
    case .sepolia:
      return [
        "https://rpc.sepolia.org",
        "https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
      ]
    case .polygon:
      return [
        "https://polygon-rpc.com",
        "https://rpc.ankr.com/polygon",
        "https://polygon.llamarpc.com"
      ]
    case .mumbai:
      return [
        "https://rpc-mumbai.maticvigil.com",
        "https://matic-mumbai.chainstacklabs.com"
      ]
    }
  }
    
  private func parseAmount(_ amount: String) throws -> BigUInt {
    guard let amountDecimal = Decimal(string: amount) else {
      throw WalletError.invalidAmount
    }
    guard Decimal(string: amount) != nil else {
      throw WalletError.invalidAmount
    }
    let weiDecimal = Decimal(string: amount)! * 1_000_000_000_000_000_000
    return BigUInt(weiDecimal.description) ?? 0
  }
    
  private func parseTokenAmount(_ amount: String, decimals: Int) throws -> BigUInt {
    guard let amountDecimal = Decimal(string: amount) else {
      throw WalletError.invalidAmount
    }
    let multiplier = pow(10.0, decimals)
    let amountInWei = amountDecimal * multiplier
    return BigUInt(amountInWei.description) ?? 0
  }
  
  func getFaucetURL(for network: SupportedNetwork) -> URL? {
    guard network.mode == .testnet, let address = walletAddress else {
      return nil
    }
    
    switch network {
    case .sepolia:
      return URL(string: "https://sepoliafaucet.com/?address=\(address)")
    case .mumbai:
      return URL(string: "https://faucet.polygon.technology/?network=mumbai&address=\(address)")
    default:
      return nil
    }
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
  case invalidNetwork
    
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
    case .invalidNetwork:
      "Invalid network for test tokens"
    }
  }
}
