import CoreImage.CIFilterBuiltins
import SwiftUI

struct ReceiveView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var walletManager: WalletManager
    
  var body: some View {
    NavigationView {
      VStack(spacing: 32) {
        if let address = walletManager.walletAddress {
          VStack(spacing: 24) {
            Text("Your Address")
              .font(.system(size: 20, weight: .semibold))
                        
            QRCodeView(address: address)
              .frame(width: 200, height: 200)
              .padding(16)
              .background(Color.white)
              .cornerRadius(12)
                        
            Text(address)
              .font(.system(size: 14, design: .monospaced))
              .foregroundColor(.primary)
              .padding(16)
              .background(Color.gray.opacity(0.1))
              .cornerRadius(8)
              .onTapGesture {
                UIPasteboard.general.string = address
              }
                        
            Button(action: {
              UIPasteboard.general.string = address
            }) {
              HStack {
                Image(systemName: "doc.on.doc")
                Text("Copy Address")
              }
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color.blue)
              .cornerRadius(12)
            }
          }
          .padding(24)
        }
                
        Spacer()
      }
      .navigationTitle("Receive")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

struct QRCodeView: View {
  let address: String
  let context = CIContext()
  let filter = CIFilter.qrCodeGenerator()
    
  var body: some View {
    Image(uiImage: generateQRCode(from: address))
      .interpolation(.none)
      .resizable()
      .scaledToFit()
  }
    
  private func generateQRCode(from string: String) -> UIImage {
    filter.message = Data(string.utf8)
        
    if let outputImage = filter.outputImage {
      if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
        return UIImage(cgImage: cgimg)
      }
    }
        
    return UIImage(systemName: "xmark.circle") ?? UIImage()
  }
}
