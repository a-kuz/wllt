import SwiftUI

struct AuthenticationView: View {
  @EnvironmentObject var authManager: AuthenticationManager
  @State private var pin: String = ""
  @State private var showPINEntry = false
  @State private var errorMessage: String?
  @FocusState private var isPINFocused: Bool
    
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          isPINFocused = true
        }
      }
    }
  }
    
  private var pinEntryView: some View {
    VStack(spacing: 24) {
      Text("Enter PIN")
        .font(.system(size: 18, weight: .medium))
      
      HStack(spacing: 16) {
        ForEach(0..<6) { index in
          Circle()
            .fill(index < pin.count ? Color.blue : Color.gray.opacity(0.3))
            .frame(width: 16, height: 16)
        }
      }
      .padding(.vertical, 8)
      
      TextField("", text: $pin)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .focused($isPINFocused)
        .opacity(0)
        .frame(width: 0, height: 0)
        .onChange(of: pin) { newValue in
          let filtered = newValue.filter { $0.isNumber }
          pin = String(filtered.prefix(6))
          
          if pin.count == 6 {
            verifyPIN()
          }
        }
    }
  }
    
  private func authenticate() {
    Task {
      let success = await authManager.authenticate()
      if !success {
        showPINEntry = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          isPINFocused = true
        }
      }
    }
  }
    
  private func verifyPIN() {
    if authManager.verifyPIN(pin) {
      authManager.isAuthenticated = true
      errorMessage = nil
      pin = ""
    } else {
      errorMessage = "Invalid PIN"
      pin = ""
      isPINFocused = true
    }
  }
}
