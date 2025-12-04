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
      .onAppear {
        Task {
          await walletManager.loadBalances()
          await walletManager.loadTokens()
        }
      }
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
        .frame(maxWidth: .infinity, alignment: .leading)
            
      if walletManager.balances.isEmpty {
        VStack(spacing: 8) {
          ZStack {
            Circle()
              .fill(Color.gray.opacity(0.08))
              .frame(width: 50, height: 50)
            Image(systemName: "wallet.pass.fill")
              .font(.system(size: 24))
              .foregroundColor(.secondary.opacity(0.4))
          }
          
          VStack(spacing: 4) {
            Text("No balances found")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.primary)
            Text("Your network balances will appear here once they are loaded")
              .font(.system(size: 13))
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
      } else {
        ForEach(walletManager.balances) { balance in
          BalanceRow(balance: balance)
        }
      }
    }
  }
    
  private var tokensSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Tokens")
        .font(.system(size: 20, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
            
      if walletManager.tokens.isEmpty {
        VStack(spacing: 8) {
          ZStack {
            Circle()
              .fill(Color.gray.opacity(0.08))
              .frame(width: 50, height: 50)
            Image(systemName: "circle.grid.3x3.fill")
              .font(.system(size: 24))
              .foregroundColor(.secondary.opacity(0.4))
          }
          
          VStack(spacing: 4) {
            Text("No tokens found")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.primary)
            Text("ERC-20 tokens associated with your wallet will be displayed here")
              .font(.system(size: 13))
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
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
