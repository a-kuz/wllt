import SwiftUI

struct WalletView: View {
  @EnvironmentObject var walletManager: WalletManager
  @State private var showReceive = false
  @State private var showSend = false
    
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          if let address = walletManager.walletAddress {
            addressSection(address: address)
          }
                    
          balancesSection
                    
          tokensSection
                    
          actionButtons
        }
        .padding(24)
      }
      .navigationTitle("Wallet")
      .refreshable {
        await walletManager.loadBalances()
        await walletManager.loadTokens()
      }
      .sheet(isPresented: $showReceive) {
        ReceiveView()
      }
      .sheet(isPresented: $showSend) {
        SendView()
      }
    }
  }
    
  private func addressSection(address: String) -> some View {
    VStack(spacing: 12) {
      Text("Your Address")
        .font(.system(size: 14))
        .foregroundColor(.secondary)
            
      Text(address)
        .font(.system(size: 14, design: .monospaced))
        .foregroundColor(.primary)
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
          UIPasteboard.general.string = address
        }
    }
  }
    
  private var balancesSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Balances")
        .font(.system(size: 20, weight: .bold))
            
      ForEach(walletManager.balances) { balance in
        BalanceRow(balance: balance)
      }
    }
  }
    
  private var tokensSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Tokens")
        .font(.system(size: 20, weight: .bold))
            
      if walletManager.tokens.isEmpty {
        Text("No tokens found")
          .font(.system(size: 16))
          .foregroundColor(.secondary)
          .padding(.vertical, 16)
      } else {
        ForEach(walletManager.tokens) { token in
          TokenRow(token: token)
        }
      }
    }
  }
    
  private var actionButtons: some View {
    HStack(spacing: 16) {
      Button(action: {
        showReceive = true
      }) {
        VStack(spacing: 8) {
          Image(systemName: "qrcode")
            .font(.system(size: 32))
          Text("Receive")
            .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(.blue)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
      }
            
      Button(action: {
        showSend = true
      }) {
        VStack(spacing: 8) {
          Image(systemName: "paperplane.fill")
            .font(.system(size: 32))
          Text("Send")
            .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Color.blue)
        .cornerRadius(12)
      }
    }
  }
}

struct BalanceRow: View {
  let balance: NetworkBalance
    
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(balance.network.name)
          .font(.system(size: 16, weight: .medium))
        Text(balance.symbol)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
            
      Spacer()
            
      Text(balance.balance)
        .font(.system(size: 18, weight: .semibold))
    }
    .padding(16)
    .background(Color.gray.opacity(0.05))
    .cornerRadius(12)
  }
}

struct TokenRow: View {
  let token: Token
    
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(token.name)
          .font(.system(size: 16, weight: .medium))
        Text(token.symbol)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
            
      Spacer()
            
      VStack(alignment: .trailing, spacing: 4) {
        Text(token.balance)
          .font(.system(size: 18, weight: .semibold))
        Text(token.network.name)
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
    }
    .padding(16)
    .background(Color.gray.opacity(0.05))
    .cornerRadius(12)
  }
}
