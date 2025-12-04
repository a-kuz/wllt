import Foundation

struct NetworkBalance: Identifiable {
  let id = UUID()
  let network: SupportedNetwork
  let balance: String
  let symbol: String
}

enum NetworkMode: String, CaseIterable {
  case mainnet
  case testnet
  
  var displayName: String {
    switch self {
    case .mainnet:
      "Mainnet"
    case .testnet:
      "Testnet"
    }
  }
}

enum SupportedNetwork: String, CaseIterable, Hashable {
  case ethereum
  case sepolia
  case polygon
  case mumbai
    
  var name: String {
    switch self {
    case .ethereum:
      "Ethereum"
    case .sepolia:
      "Sepolia"
    case .polygon:
      "Polygon"
    case .mumbai:
      "Mumbai"
    }
  }
    
  var nativeSymbol: String {
    switch self {
    case .ethereum, .sepolia:
      "ETH"
    case .polygon, .mumbai:
      "MATIC"
    }
  }
    
  var rpcUrl: String {
    switch self {
    case .ethereum:
      "https://ethereum.publicnode.com"
    case .sepolia:
      "https://rpc.sepolia.org"
    case .polygon:
      "https://polygon-rpc.com"
    case .mumbai:
      "https://rpc-mumbai.maticvigil.com"
    }
  }
    
  var explorerUrl: String {
    switch self {
    case .ethereum:
      "https://etherscan.io"
    case .sepolia:
      "https://sepolia.etherscan.io"
    case .polygon:
      "https://polygonscan.com"
    case .mumbai:
      "https://mumbai.polygonscan.com"
    }
  }
    
  var explorerAPIUrl: String {
    switch self {
    case .ethereum:
      "https://api.etherscan.io/api"
    case .sepolia:
      "https://api-sepolia.etherscan.io/api"
    case .polygon:
      "https://api.polygonscan.com/api"
    case .mumbai:
      "https://api-testnet.polygonscan.com/api"
    }
  }
  
  var chainId: UInt64 {
    switch self {
    case .ethereum:
      1
    case .sepolia:
      11155111
    case .polygon:
      137
    case .mumbai:
      80001
    }
  }
  
  var mode: NetworkMode {
    switch self {
    case .ethereum, .polygon:
      .mainnet
    case .sepolia, .mumbai:
      .testnet
    }
  }
  
  static func from(chainId: UInt64) -> SupportedNetwork? {
    switch chainId {
    case 1:
      return .ethereum
    case 11155111:
      return .sepolia
    case 137:
      return .polygon
    case 80001:
      return .mumbai
    default:
      return nil
    }
  }
  
  static func all(for mode: NetworkMode) -> [SupportedNetwork] {
    allCases.filter { $0.mode == mode }
  }
}
