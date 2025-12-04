import SwiftUI

struct SetPINView: View {
  @EnvironmentObject var authManager: AuthenticationManager
  @State private var pin: String = ""
  @State private var confirmPin: String = ""
  @State private var step: PINStep = .enter
  @State private var errorMessage: String?
  @FocusState private var isPINFocused: Bool
  
  enum PINStep {
    case enter
    case confirm
  }
  
  var body: some View {
    VStack(spacing: 32) {
      Spacer()
      
      Image(systemName: "lock.shield")
        .font(.system(size: 80))
        .foregroundColor(.blue)
      
      Text(step == .enter ? "Set PIN Code" : "Confirm PIN Code")
        .font(.system(size: 32, weight: .bold))
      
      Text("Create a PIN code to secure your wallet")
        .font(.system(size: 16))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
      
      VStack(spacing: 24) {
        HStack(spacing: 16) {
          ForEach(0..<6) { index in
            Circle()
              .fill(index < currentPIN.count ? Color.blue : Color.gray.opacity(0.3))
              .frame(width: 16, height: 16)
          }
        }
        .padding(.vertical, 8)
        
        TextField("", text: Binding(
          get: { currentPIN },
          set: { newValue in
            let filtered = newValue.filter { $0.isNumber }
            let limited = String(filtered.prefix(6))
            
            if step == .enter {
              pin = limited
              if pin.count == 6 {
                isPINFocused = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                  withAnimation {
                    step = .confirm
                  }
                }
              }
            } else if step == .confirm {
              if limited != confirmPin {
                confirmPin = limited
                if confirmPin.count == 6 {
                  verifyAndSetPIN()
                }
              }
            }
          }
        ))
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .focused($isPINFocused)
        .frame(width: 1, height: 1)
        .opacity(0.01)
        .offset(x: -1000, y: -1000)
        .onChange(of: step) { newStep in
          if newStep == .confirm {
            confirmPin = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              isPINFocused = true
            }
          }
        }
        
        if step == .confirm {
          Button(action: {
            withAnimation {
              step = .enter
              confirmPin = ""
              isPINFocused = true
            }
          }) {
            Text("Back")
              .font(.system(size: 16))
              .foregroundColor(.blue)
          }
        }
      }
      
      if let error = errorMessage {
        Text(error)
          .font(.system(size: 14))
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }
      
      Spacer()
    }
    .padding(24)
    .task {
      try? await Task.sleep(nanoseconds: 500_000_000)
      isPINFocused = true
    }
  }
  
  private var currentPIN: String {
    step == .enter ? pin : confirmPin
  }
  
  private func verifyAndSetPIN() {
    guard pin == confirmPin else {
      errorMessage = "PIN codes do not match"
      confirmPin = ""
      isPINFocused = true
      return
    }
    
    guard pin.count == 6 else {
      errorMessage = "PIN must be 6 digits"
      confirmPin = ""
      isPINFocused = true
      return
    }
    
    do {
      try authManager.setPIN(pin)
      errorMessage = nil
      authManager.objectWillChange.send()
    } catch {
      errorMessage = "Failed to set PIN: \(error.localizedDescription)"
      confirmPin = ""
      isPINFocused = true
    }
  }
}
