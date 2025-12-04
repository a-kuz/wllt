import Foundation

struct NetworkBalance: Identifiable {
  let id = UUID()
  let network: SupportedNetwork
  let balance: String
  let symbol: String
}

enum SupportedNetwork: String, CaseIterable {
  case ethereum
  case polygon
    
  var name: String {
    switch self {
    case .ethereum:
      "Ethereum"
    case .polygon:
      "Polygon"
    }
  }
    
  var nativeSymbol: String {
    switch self {
    case .ethereum:
      "ETH"
    case .polygon:
      "MATIC"
    }
  }
    
  var rpcUrl: String {
    switch self {
    case .ethereum:
      "https://eth.llamarpc.com"
    case .polygon:
      "https://polygon.llamarpc.com"
    }
  }
    
  var explorerUrl: String {
    switch self {
    case .ethereum:
      "https://etherscan.io"
    case .polygon:
      "https://polygonscan.com"
    }
  }
    
  var explorerAPIUrl: String {
    switch self {
    case .ethereum:
      "https://api.etherscan.io/api"
    case .polygon:
      "https://api.polygonscan.com/api"
    }
  }
}
