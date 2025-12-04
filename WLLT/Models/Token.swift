import Foundation

struct Token: Identifiable, Hashable {
  let id = UUID()
  let address: String
  let name: String
  let symbol: String
  let balance: String
  let decimals: Int
  let network: SupportedNetwork
}

struct Transaction: Identifiable {
  let id = UUID()
  let hash: String
  let from: String
  let to: String
  let amount: String
  let symbol: String
  let timestamp: Date
  let network: SupportedNetwork
  let type: TransactionType
}

enum TransactionType {
  case sent
  case received
}
