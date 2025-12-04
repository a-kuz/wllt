import Foundation

enum ExplorerAPI {
  static func getBaseURL(for network: SupportedNetwork) -> String {
    network.explorerAPIUrl
  }

  static func getAPIKey(for _: SupportedNetwork) -> String? {
    nil
  }
  
  static func getV2URL(for network: SupportedNetwork) -> String {
    let baseUrl = network.explorerAPIUrl.replacingOccurrences(of: "/api", with: "/v2/api")
    return baseUrl
  }
}

struct EtherscanResponse: Codable {
  let status: String
  let message: String
  let result: [EtherscanTransaction]
}

struct EtherscanTokenResponse: Codable {
  let status: String
  let message: String
  let result: [EtherscanTokenTransfer]
}

struct EtherscanTransaction: Codable {
  let blockNumber: String
  let timeStamp: String
  let hash: String
  let from: String
  let to: String
  let value: String
  let tokenName: String?
  let tokenSymbol: String?
  let tokenDecimal: String?
  let contractAddress: String?
  let isError: String?

  enum CodingKeys: String, CodingKey {
    case blockNumber
    case timeStamp
    case hash
    case from
    case to
    case value
    case tokenName
    case tokenSymbol
    case tokenDecimal
    case contractAddress
    case isError
  }
}

struct EtherscanTokenTransfer: Codable {
  let blockNumber: String
  let timeStamp: String
  let hash: String
  let from: String
  let to: String
  let value: String
  let tokenName: String
  let tokenSymbol: String
  let tokenDecimal: String
  let contractAddress: String
}
