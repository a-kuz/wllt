import SwiftUI

struct AuthenticationView: View {
  @EnvironmentObject var authManager: AuthenticationManager
  @State private var pin: String = ""
  @State private var showPINEntry = false
  @State private var errorMessage: String?
    
  var body: some View {
    VStack(spacing: 32) {
      Spacer()
            
      Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
        .font(.system(size: 80))
        .foregroundColor(.blue)
            
      Text("Unlock Wallet")
        .font(.system(size: 32, weight: .bold))
            
      if authManager.biometricType != .none {
        Button(action: {
          authenticate()
        }) {
          Text("Authenticate")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
      } else {
        pinEntryView
      }
            
      if let error = errorMessage {
        Text(error)
          .font(.system(size: 14))
          .foregroundColor(.red)
      }
            
      Spacer()
    }
    .onAppear {
      if authManager.biometricType != .none {
        authenticate()
      } else {
        showPINEntry = true
      }
    }
  }
    
  private var pinEntryView: some View {
    VStack(spacing: 16) {
      Text("Enter PIN")
        .font(.system(size: 18, weight: .medium))
            
      SecureField("PIN", text: $pin)
        .keyboardType(.numberPad)
        .textFieldStyle(.roundedBorder)
        .frame(width: 200)
            
      Button(action: {
        verifyPIN()
      }) {
        Text("Unlock")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)
          .frame(width: 200)
          .frame(height: 56)
          .background(Color.blue)
          .cornerRadius(12)
      }
    }
  }
    
  private func authenticate() {
    Task {
      let success = await authManager.authenticate()
      if !success {
        showPINEntry = true
      }
    }
  }
    
  private func verifyPIN() {
    if authManager.verifyPIN(pin) {
      authManager.isAuthenticated = true
      errorMessage = nil
    } else {
      errorMessage = "Invalid PIN"
      pin = ""
    }
  }
}
