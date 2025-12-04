import Combine
import Foundation
import KeychainAccess
import LocalAuthentication

class AuthenticationManager: ObservableObject {
  static let shared = AuthenticationManager()
    
  @Published var isAuthenticated: Bool = false
  @Published var biometricType: BiometricType = .none
    
  private let keychain = Keychain(service: "com.wllt.auth")
  private let pinKey = "wallet_pin"
    
  var hasPIN: Bool {
    keychain[pinKey] != nil
  }
    
  private init() {
    checkBiometricType()
  }
    
  func checkBiometricType() {
    let context = LAContext()
    var error: NSError?
        
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
      switch context.biometryType {
      case .faceID:
        biometricType = .faceID
      case .touchID:
        biometricType = .touchID
      default:
        biometricType = .none
      }
    } else {
      biometricType = .none
    }
  }
    
  func authenticate() async -> Bool {
    let context = LAContext()
    var error: NSError?
        
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      return await authenticateWithPIN()
    }
        
    do {
      let success = try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: "Authenticate to access your wallet"
      )
            
      await MainActor.run {
        isAuthenticated = success
      }
            
      return success
    } catch {
      return await authenticateWithPIN()
    }
  }
    
  func authenticateWithPIN() async -> Bool {
    guard keychain[pinKey] != nil else {
      return false
    }
        
    return false
  }
    
  func setPIN(_ pin: String) throws {
    try keychain.set(pin, key: pinKey)
  }
    
  func verifyPIN(_ pin: String) -> Bool {
    guard let storedPIN = keychain[pinKey] else {
      return false
    }
    return pin == storedPIN
  }
    
  func logout() {
    isAuthenticated = false
  }
}

enum BiometricType {
  case none
  case touchID
  case faceID
}
