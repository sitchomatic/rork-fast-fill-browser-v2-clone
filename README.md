# Fast Fill Browser

> A security-focused iOS browser with integrated credential vault, auto-fill automation, and credential rotation — built with SwiftUI and SwiftData.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)
- [Security](#security)
- [Data Storage](#data-storage)
- [Key Concepts](#key-concepts)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Limitations & Future Work](#limitations--future-work)

---

## Overview

Fast Fill Browser is a native iOS application that combines a full-featured web browser with a password manager and login automation engine. It is purpose-built for users who manage multiple credentials across various domains. The app provides rapid credential switching, automated form filling, and per-domain session management.

The app wraps WKWebView in a SwiftUI shell and layers on a credential vault protected by biometric authentication (Face ID / Touch ID / Optic ID). Passwords are stored exclusively in the iOS Keychain — never in the local database — while credential metadata, browsing history, bookmarks, and site-specific settings are persisted via SwiftData.

**Primary use cases:**

- Managing dozens of credentials across multiple related domains
- Rapidly rotating between credentials on the same site
- Automating login form submission with configurable CSS selectors
- Navigating domain aliases via shorthand shortcuts
- Clearing sessions ("burning") per domain for privacy

---

## Features

### Browser

| Feature | Description |
|---|---|
| **Multi-tab browsing** | Open, close, and switch between multiple browser tabs with snapshot previews |
| **URL alias shortcuts** | Type short aliases (e.g., `joep.win`) to navigate to full URLs instantly |
| **HTTPS indicator** | Visual lock icon showing connection security status |
| **Ad & tracking blocker** | Built-in content rule list blocking 20+ ad/tracking domains (DoubleClick, Google Analytics, Hotjar, etc.) |
| **DNS pre-warming** | Pre-resolves DNS for your most-visited domains on app launch for faster navigation |
| **Search engine selection** | Choose between Google, DuckDuckGo, or Bing as the default search engine |
| **Browsing history** | Searchable, date-grouped history with clear-all capability |
| **Bookmarks** | Save and organize favorite pages |

### Credential Vault

| Feature | Description |
|---|---|
| **Biometric lock** | Vault protected by Face ID, Touch ID, or Optic ID with device passcode fallback |
| **Credential management** | Add, edit, delete, and search credentials by domain |
| **CSV import** | Import credentials from Chrome, Firefox, or generic CSV formats (RFC 4180 compliant) |
| **Password generator** | Cryptographically secure random passwords (8–64 chars) with configurable character types and strength meter |
| **Keychain storage** | Passwords stored exclusively in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection |

### Auto-Fill & Automation

| Feature | Description |
|---|---|
| **Smart auto-fill** | Detects login forms and fills credentials automatically on page load |
| **CSS selector customization** | Configure per-domain selectors for username, password, and submit button fields |
| **Credential rotation (RC)** | Cycle through multiple stored credentials for the same domain with a single action |
| **Auto-login** | Automatically submit the login form after filling credentials |
| **Sure-login** | Retry form submission with configurable delay and retry count for unreliable login pages |
| **Burn** | Clear all cookies and website data for the current domain, then reload the page |
| **Auto RC + Auto Burn** | Combine credential rotation with automatic session clearing for full credential cycling |
| **Credential pre-warming** | Pre-computes the fill script for the next credential while the current one is in use |
| **Offer to save** | Detects form submissions and prompts to save new credentials |

---

## Architecture

The app follows a **Model-View-ViewModel (MVVM)** architecture built on modern Swift patterns:

```
┌─────────────────────────────────────────────────┐
│                    Views (SwiftUI)               │
│  BrowserView · VaultView · LockScreenView · ...  │
└──────────────────────┬──────────────────────────┘
                       │ @Observable
┌──────────────────────▼──────────────────────────┐
│              ViewModels                          │
│  BrowserViewModel · VaultViewModel               │
└──────────┬───────────────────────┬──────────────┘
           │                       │
┌──────────▼──────────┐  ┌────────▼──────────────┐
│      Services        │  │   DI Container        │
│  BiometricService    │  │  @Dependency wrapper   │
│  KeychainService     │  │  BiometricClient       │
│  JavaScriptInjection │  │  KeychainClient        │
│  PasswordGenerator   │  │  JavaScriptInjection   │
│  CredentialImport    │  │     Client             │
│  URLAliasService     │  └───────────────────────┘
│  DNSPrewarmService   │
│  WebViewConfigFactory│
└──────────┬──────────┘
           │
┌──────────▼──────────┐  ┌───────────────────────┐
│   Models (SwiftData) │  │   DTOs (Sendable)     │
│  Credential          │  │  CredentialDTO        │
│  SiteSetting         │  │  SiteSettingDTO       │
│  BrowsingHistoryEntry│  │  BookmarkDTO          │
│  Bookmark            │  │  BrowsingHistoryEntry │
│  BrowserTab          │  │     DTO               │
└──────────────────────┘  └───────────────────────┘
```

### Key Architectural Patterns

- **`@Observable` macro** — ViewModels use Swift Observation for reactive UI updates (replaces `ObservableObject`/`@Published`)
- **SwiftData** — Modern persistence layer replacing CoreData, with `@Model` annotations and `#Index`/`#Unique` macros
- **Dependency Injection** — Custom `DependencyContainer` with `@Dependency` property wrapper for testable service access
- **DTO pattern** — `Sendable` data transfer objects bridge SwiftData models (non-Sendable) across actor boundaries
- **Global Actors** — `TabIsolationActor` and `WebKitConfigActor` provide thread safety for WebKit operations
- **Structured Concurrency** — `async/await` throughout with cancellable `Task` handles for operations like Sure-Login retries
- **Cache-aside pattern** — In-memory caches for credentials, passwords, and site settings with explicit invalidation

---

## Project Structure

> **Note:** The iOS source code is located in the `ios/` directory. The tree below reflects the project layout when the app source is present.

```
ios/
├── FastFillBrowser02/
│   ├── FastFillBrowser02App.swift          # App entry point, SwiftData container setup
│   ├── ContentView.swift                   # Root view (biometric gate → browser)
│   │
│   ├── Actors/
│   │   ├── TabIsolationActor.swift         # Global actor for tab operations
│   │   └── WebKitConfigActor.swift         # Global actor for WebKit configuration
│   │
│   ├── DI/
│   │   ├── DependencyContainer.swift       # DI container with @Dependency wrapper
│   │   ├── BiometricClient.swift           # Testable biometric interface
│   │   ├── JavaScriptInjectionClient.swift # Testable JS injection interface
│   │   ├── KeychainClient.swift            # Testable Keychain interface
│   │   └── ServiceErrors.swift             # Typed errors (KeychainError, BiometricError)
│   │
│   ├── DTOs/
│   │   ├── BookmarkDTO.swift               # Sendable bookmark transfer object
│   │   ├── BrowsingHistoryEntryDTO.swift   # Sendable history transfer object
│   │   ├── CredentialDTO.swift             # Sendable credential transfer object
│   │   └── SiteSettingDTO.swift            # Sendable site setting transfer object
│   │
│   ├── Models/
│   │   ├── Bookmark.swift                  # SwiftData model — saved pages
│   │   ├── BrowserTab.swift                # Observable tab state (not persisted)
│   │   ├── BrowsingHistoryEntry.swift      # SwiftData model — visit history
│   │   ├── Credential.swift                # SwiftData model — credential metadata
│   │   └── SiteSetting.swift               # SwiftData model — per-domain config
│   │
│   ├── Services/
│   │   ├── BiometricService.swift          # Face ID / Touch ID authentication
│   │   ├── CredentialImportService.swift   # CSV parsing (Chrome/Firefox/generic)
│   │   ├── DNSPrewarmService.swift         # Pre-resolves DNS for top domains
│   │   ├── JavaScriptInjectionService.swift# Generates JS for form detection & fill
│   │   ├── KeychainService.swift           # iOS Keychain CRUD operations
│   │   ├── PasswordGeneratorService.swift  # Secure random password generation
│   │   ├── URLAliasService.swift           # Short alias → full URL resolution
│   │   └── WebViewConfigurationFactory.swift # WKWebView config with content rules
│   │
│   ├── ViewModels/
│   │   ├── BrowserViewModel.swift          # Core browser state & business logic
│   │   └── VaultViewModel.swift            # Credential list state & operations
│   │
│   └── Views/
│       ├── AppSettingsView.swift           # App settings form
│       ├── BookmarksView.swift             # Bookmark list
│       ├── BrowserView.swift               # Main browser interface
│       ├── CredentialDetailView.swift      # Single credential view/edit
│       ├── CredentialFormView.swift        # Add new credential form
│       ├── CredentialPickerSheet.swift     # Credential selection modal
│       ├── HistoryView.swift               # Browsing history list
│       ├── ImportCredentialsView.swift     # CSV import wizard
│       ├── LockScreenView.swift            # Biometric unlock screen
│       ├── PasswordGeneratorView.swift     # Password generator with strength meter
│       ├── SiteSettingsView.swift          # Per-domain auto-fill configuration
│       ├── TabManagerView.swift            # Tab grid with snapshots
│       ├── ToastView.swift                 # Notification toast overlay
│       ├── URLAliasListView.swift          # URL alias directory
│       ├── VaultView.swift                 # Credential vault list
│       └── WebViewWrapper.swift            # UIViewRepresentable WKWebView bridge
│
└── .gitignore
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| **UI Framework** | SwiftUI with `@Observable` (Swift 5.9+) |
| **Persistence** | SwiftData (`@Model`, `#Index`, `#Unique`) |
| **Browser Engine** | WebKit (`WKWebView`, `WKContentRuleList`, `WKNavigationDelegate`) |
| **Authentication** | LocalAuthentication (Face ID / Touch ID / Optic ID) |
| **Secret Storage** | Security framework (iOS Keychain via `SecItemAdd`, `SecItemCopyMatching`) |
| **Cryptography** | `SecRandomCopyBytes` for password generation |
| **Concurrency** | Structured concurrency (`async/await`), `@globalActor`, `Sendable` |
| **Platform** | iOS (native Swift, no cross-platform dependencies) |

---

## Security

### Password Storage

Passwords are **never** stored in the SwiftData database. All secrets are kept in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection — meaning they are:

- Encrypted at rest by the Secure Enclave
- Only accessible when the device is unlocked
- Non-transferable to other devices (not included in backups)

The SwiftData `Credential` model stores only metadata: domain, username, notes, timestamps, and usage count.

### Biometric Authentication

The vault is gated behind biometric authentication on app launch (configurable via settings). The app supports:

- Face ID
- Touch ID
- Optic ID
- Device passcode fallback

### JavaScript Injection Safety

Form-filling JavaScript carefully escapes all user input (quotes, newlines, backslashes) before injection into web pages. Field detection uses visibility checks (`offsetParent !== null`) and type-based heuristics to target the correct form fields.

### Content Blocking

A built-in `WKContentRuleList` blocks requests to known ad and tracking domains including DoubleClick, Google Analytics, Facebook Pixel, Hotjar, and others.

### Cryptographic Password Generation

The password generator uses `SecRandomCopyBytes` (Apple's cryptographically secure random number generator) with rejection sampling to eliminate modulo bias, ensuring generated passwords are truly random.

---

## Data Storage

| Data | Storage Location | Notes |
|---|---|---|
| **Passwords** | iOS Keychain | Encrypted, device-only, never in database |
| **Credential metadata** | SwiftData | Domain, username, notes, timestamps, usage count |
| **Site settings** | SwiftData | CSS selectors, auto-fill/login flags per domain |
| **Browsing history** | SwiftData | URL, title, domain, timestamp |
| **Bookmarks** | SwiftData | URL, title, domain, sort order |
| **App settings** | `@AppStorage` (UserDefaults) | Biometric toggle, search engine, auto-fill prefs |
| **Runtime caches** | In-memory | Credential, password, and site setting caches (cleared on invalidation) |

---

## Key Concepts

### Credential Rotation (RC)

When multiple credentials exist for the same domain, the Rotate Credential action cycles to the next credential in the list, fills the form, and optionally triggers auto-login. The app pre-computes the fill script for the next credential in the background for instant switching.

### Sure-Login

For unreliable login pages, Sure-Login retries the form submission at a configurable interval (default: 2 seconds) up to a configurable number of attempts (default: 3). The retry task is cancellable — navigating away or switching tabs automatically cancels it.

### Burn

The Burn action clears all cookies and website data (`WKWebsiteDataStore`) for the current domain, deletes matching history entries, and reloads the page. This provides per-domain session isolation without affecting other sites. Combined with Auto RC, this enables full credential cycling with clean sessions.

### URL Aliases

URL aliases map short keywords to full URLs. For example, typing `joep.win` in the URL bar resolves to the full login page URL. Aliases are organized into profiles and support prefix/substring matching for autocomplete suggestions.

### DNS Pre-warming

On app launch, the `DNSPrewarmService` identifies the top 10 most-visited domains and fires background HEAD requests to pre-populate the DNS cache, reducing latency on the first navigation.

---

## Getting Started

### Prerequisites

- **Xcode 15+** (Swift 5.9 or later)
- **iOS 17.0+** deployment target (required for SwiftData and `@Observable`)
- A physical device is recommended for biometric features (Face ID / Touch ID)

### Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/sitchomatic/rork-fast-fill-browser-v2-clone.git
   cd rork-fast-fill-browser-v2-clone
   ```

2. Open the Xcode project or workspace from the repository root:
   ```bash
   open ios/FastFillBrowser02.xcodeproj
   ```
   *If the repository includes an `.xcworkspace`, open that instead.*

3. Select your target device or simulator.

4. Build and run (`⌘R`).

> **Note:** Biometric authentication requires a physical device or a simulator with enrolled biometrics (Simulator → Features → Face ID / Touch ID → Enrolled).

---

## Configuration

### App Settings (Runtime)

Access via the gear icon in the browser toolbar:

| Setting | Default | Description |
|---|---|---|
| Require biometric on launch | On | Lock the app behind biometric auth |
| Auto-fill on page load | Off | Automatically fill credentials when a login form is detected |
| Offer to save passwords | On | Prompt to save credentials after form submission |
| Search engine | Google | Default search engine for URL bar queries |

### Per-Site Settings

Access via the site settings icon for the current domain:

| Setting | Description |
|---|---|
| Username CSS selector | Custom CSS selector for the username field |
| Password CSS selector | Custom CSS selector for the password field |
| Submit button CSS selector | Custom CSS selector for the login button |
| Auto-login | Automatically submit the form after filling |
| Sure-login | Retry submission on failure |
| Sure-login retry count | Number of retry attempts |
| Sure-login delay | Seconds between retries |
| Auto rotate credential | Automatically cycle to the next credential |
| Auto burn on RC | Clear session data before rotating credentials |

---

## Limitations & Future Work

| Area | Current State | Potential Improvement |
|---|---|---|
| **TOTP / 2FA** | Data field exists (`totpSecret`) but generation is not implemented | Implement TOTP code generation and auto-fill |
| **Cloud sync** | All data is local to the device | Add iCloud sync or encrypted backup/export |
| **URL aliases** | Hardcoded profiles (Joe Fortune, Ignition Casino) | Externalize to a configurable file or remote config |
| **Ad blocking rules** | Static JSON list of 20+ domains | Support dynamic rule updates or user-managed lists |
| **Form detection** | Heuristic-based (field type, visibility) | Improve handling of shadow DOM and complex layouts |
| **Error handling** | Some Keychain errors fail silently | Add structured logging and user-facing error messages |
| **Export** | No credential export | Add CSV or encrypted export for backup |
| **Accessibility** | Basic SwiftUI defaults | Audit and improve VoiceOver support |

---

## Credits

Created by Rork.
