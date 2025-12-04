import SwiftUI

struct SessionsView: View {
  @StateObject private var wcManager = WalletConnectManager.shared
  @State private var showDisconnectAlert = false
  @State private var selectedSessionTopic: String?
  
  var body: some View {
    NavigationView {
      List {
        if wcManager.sessions.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "link.badge.plus")
              .font(.system(size: 36))
              .foregroundColor(.secondary)
            Text("No active connections")
              .font(.system(size: 16, weight: .medium))
            Text("Connect to a dApp to get started")
              .font(.system(size: 13))
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
        } else {
          ForEach(wcManager.sessions, id: \.topic) { session in
            SessionRow(session: session) {
              selectedSessionTopic = session.topic
              showDisconnectAlert = true
            }
          }
        }
      }
      .navigationTitle("Connected dApps")
      .refreshable {
        wcManager.loadSessions()
      }
      .alert("Disconnect", isPresented: $showDisconnectAlert) {
        Button("Cancel", role: .cancel) {
          selectedSessionTopic = nil
        }
        Button("Disconnect", role: .destructive) {
          if let topic = selectedSessionTopic {
            disconnectSession(topic: topic)
          }
        }
      } message: {
        Text("Are you sure you want to disconnect this dApp?")
      }
    }
  }
  
  private func disconnectSession(topic: String) {
    Task {
      do {
        try await wcManager.disconnect(sessionTopic: topic)
      } catch {
        print("Failed to disconnect: \(error)")
      }
    }
  }
}

struct SessionRow: View {
  let session: Session
  let onDisconnect: () -> Void
  
  var body: some View {
    HStack(spacing: 12) {
      if let iconURL = session.peer.icons.first,
         let url = URL(string: iconURL) {
        AsyncImage(url: url) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
        } placeholder: {
          Image(systemName: "app.fill")
            .foregroundColor(.secondary)
        }
        .frame(width: 44, height: 44)
        .cornerRadius(8)
      } else {
        Image(systemName: "app.fill")
          .font(.system(size: 24))
          .foregroundColor(.secondary)
          .frame(width: 44, height: 44)
      }
      
      VStack(alignment: .leading, spacing: 4) {
        Text(session.peer.name)
          .font(.system(size: 16, weight: .medium))
        Text(session.peer.url)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      
      Spacer()
      
      Button(action: onDisconnect) {
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(.red)
      }
    }
    .padding(.vertical, 4)
  }
}
