# WLLT - Simple Crypto Wallet

A simple and secure non-custodial cryptocurrency wallet for iOS, Android, and Chrome extension.

## Features

- **Non-custodial**: Seed phrase stored only on device in Keychain
- **Simple UI**: Minimalist design focused on core functionality
- **Multi-network**: Ethereum and Polygon support
- **Security**: PIN/Face ID authentication, secure key storage
- **Core Actions**: Receive (QR code) and Send transactions

## iOS Setup

### Prerequisites

- Xcode 15.0+
- XcodeGen installed: `brew install xcodegen`
- SwiftLint installed: `brew install swiftlint`
- SwiftFormat installed: `brew install swiftformat`
- Swift 5.9+

### Build

```bash
xcodegen generate
open WLLT.xcodeproj
```

Then build and run in Xcode.

### Code Quality

Run linting and formatting:

```bash
make check
```

Or individually:

```bash
make lint    # Run SwiftLint
make format  # Run SwiftFormat
```

## Project Structure

```
WLLT/
├── App.swift                 # App entry point
├── ContentView.swift         # Root view
├── Models/
│   ├── WalletManager.swift   # Wallet management & Web3 integration
│   ├── AuthenticationManager.swift # PIN/Face ID auth
│   ├── NetworkBalance.swift  # Network & balance models
│   ├── Token.swift           # Token & transaction models
│   └── ExplorerAPI.swift     # Etherscan/Polygonscan API models
└── Views/
    ├── WelcomeView.swift     # Initial screen
    ├── CreateWalletView.swift # Wallet creation
    ├── ImportWalletView.swift # Wallet import
    ├── AuthenticationView.swift # PIN/Face ID
    ├── MainView.swift        # Tab bar
    ├── WalletView.swift      # Main wallet screen
    ├── ReceiveView.swift      # Receive screen with QR
    ├── SendView.swift         # Send transaction
    ├── TransactionsView.swift # Transaction history
    └── SettingsView.swift     # Settings & seed phrase
```

## Security

- Seed phrases stored in iOS Keychain
- Biometric authentication (Face ID/Touch ID)
- PIN fallback authentication
- No server-side key storage
- All transactions signed locally

## Dependencies

- **web3swift**: Ethereum/Polygon blockchain interaction
- **KeychainAccess**: Secure key storage

## API Services

- **Etherscan API**: Transaction history and token balances for Ethereum (free tier: 5 req/sec)
- **Polygonscan API**: Transaction history and token balances for Polygon (free tier: 5 req/sec)

## Code Style

The project uses:
- **SwiftLint** for code linting (`.swiftlint.yml`)
- **SwiftFormat** for code formatting (`.swiftformat`)

Run `make check` to verify code quality before committing.
