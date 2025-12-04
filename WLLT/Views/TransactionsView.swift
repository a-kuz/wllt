import SwiftUI

struct TransactionsView: View {
  @EnvironmentObject var walletManager: WalletManager
    
  var body: some View {
    NavigationView {
      List {
        if walletManager.transactions.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "tray")
              .font(.system(size: 60))
              .foregroundColor(.gray)
            Text("No transactions yet")
              .font(.system(size: 18))
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 48)
          .listRowSeparator(.hidden)
        } else {
          ForEach(walletManager.transactions) { transaction in
            TransactionRow(transaction: transaction)
          }
        }
      }
      .navigationTitle("History")
      .refreshable {
        await walletManager.loadTransactions()
      }
    }
  }
}

struct TransactionRow: View {
  let transaction: Transaction
    
  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: transaction.type == .sent ? "arrow.up.right" : "arrow.down.left")
        .font(.system(size: 24))
        .foregroundColor(transaction.type == .sent ? .red : .green)
        .frame(width: 40)
            
      VStack(alignment: .leading, spacing: 4) {
        Text(transaction.type == .sent ? "Sent" : "Received")
          .font(.system(size: 16, weight: .medium))
                
        Text(transaction.network.name)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
                
        Text(transaction.hash.prefix(10) + "..." + transaction.hash.suffix(6))
          .font(.system(size: 12, design: .monospaced))
          .foregroundColor(.secondary)
      }
            
      Spacer()
            
      VStack(alignment: .trailing, spacing: 4) {
        Text("\(transaction.type == .sent ? "-" : "+")\(transaction.amount)")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(transaction.type == .sent ? .red : .green)
                
        Text(transaction.symbol)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 8)
  }
}
