# Amber Writer

A minimalist markdown text editor inspired by iA Writer, optimized for Daylight Computer.

## Features

- **Elegant Typography**: Times New Roman font with optimal line spacing for comfortable reading
- **iOS-style UI**: Clean, distraction-free interface using Cupertino widgets
- **Full Width Mode**: Toggle horizontal width fill for optimal vertical reading
- **Markdown Support**: Simple markdown formatting including `##` for headings
- **PDF Export**: Easy one-tap export to beautifully formatted PDF documents
- **Claude Integration**: Quick access to Claude chat with your current document
- **Auto-save**: Your work is automatically saved as you type
- **Cross-platform**: Runs on Android, iOS, and macOS

## Built For

- Primary: Daylight Computer (Android)
- Secondary: iOS and macOS

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK

### Installation

```bash
flutter pub get
```

### Running the App

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# macOS
flutter run -d macos
```

## Keyboard Shortcuts

- Access actions menu via the menu button (⋯)
- Insert headings with `##` prefix
- Full width mode toggle

## Architecture

```
lib/
├── main.dart              # App entry point
├── models/
│   └── document.dart      # Document data model
├── screens/
│   └── editor_screen.dart # Main editor interface
└── services/
    ├── storage_service.dart  # Local persistence
    └── pdf_service.dart      # PDF export functionality
```

## License

MIT

## Author

Built with Claude Code
