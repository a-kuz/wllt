import AVFoundation
import SwiftUI

struct WalletConnectView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var walletManager: WalletManager
  @StateObject private var wcManager = WalletConnectManager.shared
  @State private var uriString: String = ""
  @State private var showScanner = false
  @State private var errorMessage: String?
  @State private var isConnecting = false
  
  var body: some View {
    NavigationView {
      Form {
        Section {
          Button(action: {
            showScanner = true
          }) {
            HStack {
              Image(systemName: "qrcode.viewfinder")
              Text("Scan QR Code")
            }
          }
        }
        
        Section("Or enter URI manually") {
          TextField("wc://...", text: $uriString)
            .font(.system(.body, design: .monospaced))
            .autocapitalization(.none)
            .disableAutocorrection(true)
          
          Button(action: {
            connect()
          }) {
            HStack {
              if isConnecting {
                ProgressView()
                  .scaleEffect(0.8)
              }
              Text(isConnecting ? "Connecting..." : "Connect")
            }
          }
          .disabled(uriString.isEmpty || isConnecting)
        }
        
        if let error = errorMessage {
          Section {
            Text(error)
              .foregroundColor(.red)
              .font(.system(size: 14))
          }
        }
      }
      .navigationTitle("Connect dApp")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showScanner) {
        QRScannerView { qrCode in
          uriString = qrCode
          showScanner = false
          connect()
        }
      }
    }
  }
  
  private func connect() {
    guard !uriString.isEmpty else { return }
    
    isConnecting = true
    errorMessage = nil
    
    Task {
      do {
        try await wcManager.connect(uri: uriString)
        await MainActor.run {
          isConnecting = false
          dismiss()
        }
      } catch {
        await MainActor.run {
          isConnecting = false
          errorMessage = error.localizedDescription
        }
      }
    }
  }
}

struct QRScannerView: UIViewControllerRepresentable {
  let onQRCodeScanned: (String) -> Void
  
  func makeUIViewController(context: Context) -> QRScannerViewController {
    let controller = QRScannerViewController()
    controller.onQRCodeScanned = onQRCodeScanned
    return controller
  }
  
  func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController {
  var onQRCodeScanned: ((String) -> Void)?
  private var captureSession: AVCaptureSession?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupScanner()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    startScanning()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopScanning()
  }
  
  private func setupScanner() {
    let captureSession = AVCaptureSession()
    
    guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
      return
    }
    
    let videoInput: AVCaptureDeviceInput
    
    do {
      videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
    } catch {
      return
    }
    
    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    } else {
      return
    }
    
    let metadataOutput = AVCaptureMetadataOutput()
    
    if captureSession.canAddOutput(metadataOutput) {
      captureSession.addOutput(metadataOutput)
      
      metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
      metadataOutput.metadataObjectTypes = [.qr]
    } else {
      return
    }
    
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.frame = view.layer.bounds
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)
    
    self.captureSession = captureSession
  }
  
  private func startScanning() {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.captureSession?.startRunning()
    }
  }
  
  private func stopScanning() {
    captureSession?.stopRunning()
  }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
    if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
       let stringValue = metadataObject.stringValue {
      stopScanning()
      onQRCodeScanned?(stringValue)
      dismiss(animated: true)
    }
  }
}
