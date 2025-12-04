# Инструкция по сборке iOS приложения WLLT

## Требования

- macOS с установленным Xcode 15.0 или новее
- XcodeGen: `brew install xcodegen`
- Swift 5.9+

## Шаги сборки

1. Установите зависимости (если еще не установлены):
```bash
brew install xcodegen
```

2. Сгенерируйте Xcode проект:
```bash
xcodegen generate
```

3. Откройте проект в Xcode:
```bash
open WLLT.xcodeproj
```

4. В Xcode:
   - Выберите симулятор или подключенное устройство
   - Нажмите Cmd+R для запуска

## Настройка подписи кода

1. В Xcode откройте настройки проекта (WLLT target)
2. Перейдите в раздел "Signing & Capabilities"
3. Выберите вашу команду разработчика (Development Team)
4. Xcode автоматически настроит подпись

## Структура проекта

```
WLLT/
├── App.swift                    # Точка входа приложения
├── ContentView.swift            # Корневой view
├── Models/                      # Модели данных и бизнес-логика
│   ├── WalletManager.swift      # Управление кошельком и Web3
│   ├── AuthenticationManager.swift # PIN/Face ID аутентификация
│   ├── NetworkBalance.swift     # Модели сетей и балансов
│   └── Token.swift              # Модели токенов и транзакций
├── Views/                       # UI экраны
│   ├── WelcomeView.swift        # Экран приветствия
│   ├── CreateWalletView.swift   # Создание кошелька
│   ├── ImportWalletView.swift   # Импорт кошелька
│   ├── AuthenticationView.swift # Аутентификация
│   ├── MainView.swift           # Главный экран с табами
│   ├── WalletView.swift         # Экран кошелька
│   ├── ReceiveView.swift        # Получение средств (QR)
│   ├── SendView.swift           # Отправка средств
│   ├── TransactionsView.swift   # История транзакций
│   └── SettingsView.swift       # Настройки
└── Resources/                   # Ресурсы
    └── Assets.xcassets/         # Иконки и изображения
```

## Зависимости

- **web3swift**: Работа с блокчейном Ethereum/Polygon
- **KeychainAccess**: Безопасное хранение seed-фразы
- **LocalAuthentication**: Биометрическая аутентификация (системный фреймворк)

## Примечания

- Seed-фраза хранится только в Keychain устройства
- При первом запуске нужно создать или импортировать кошелек
- Для работы с сетями требуется интернет-соединение
- RPC endpoints используют публичные сервисы (можно заменить на свои)

