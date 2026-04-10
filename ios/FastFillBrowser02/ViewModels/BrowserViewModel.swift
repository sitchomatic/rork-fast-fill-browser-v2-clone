import SwiftUI
import SwiftData
import WebKit

enum PresentedSheet: Identifiable {
    case tabs
    case credentialPicker
    case vault
    case siteSettings(String)
    case settings
    case bookmarks
    case history
    case urlAliases

    var id: String {
        switch self {
        case .tabs: return "tabs"
        case .credentialPicker: return "credentialPicker"
        case .vault: return "vault"
        case .siteSettings(let d): return "siteSettings_\(d)"
        case .settings: return "settings"
        case .bookmarks: return "bookmarks"
        case .history: return "history"
        case .urlAliases: return "urlAliases"
        }
    }
}

@Observable
@MainActor
class BrowserViewModel {
    var tabs: [BrowserTab] = []
    var activeTabIndex: Int = 0
    var urlBarText: String = ""
    var presentedSheet: PresentedSheet?
    var isShowingSaveCredentialAlert: Bool = false
    var toastMessage: String?
    var toastVisible: Bool = false
    var currentRotationIndex: Int = 0
    var matchingCredentials: [Credential] = []
    var detectedUsername: String = ""
    var detectedPassword: String = ""
    var isAutoSubmitting: Bool = false
    var aliasSuggestions: [URLAlias] = []

    private var modelContext: ModelContext?
    private var credentialCache: [String: [Credential]] = [:]
    private var passwordCache: [String: String] = [:]
    private var siteSettingCache: [String: SiteSetting] = [:]
    private var missingSiteSettingDomains = Set<String>()
    private var pendingFillScript: String?
    private var pendingFillScriptIndex: Int?
    private var historyDebounceTask: Task<Void, Never>?
    private var lastHistoryURL: String = ""
    private var sureLoginTask: Task<Void, Never>?
    private var toastHideTask: Task<Void, Never>?

    var activeTab: BrowserTab? {
        guard tabs.indices.contains(activeTabIndex) else { return nil }
        return tabs[activeTabIndex]
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        if tabs.isEmpty {
            addNewTab()
        }
    }

    func addNewTab(url: URL? = nil) {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        urlBarText = url?.absoluteString ?? ""
    }

    func closeTab(at index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }

        let newActiveTabIndex: Int
        if index < activeTabIndex {
            newActiveTabIndex = activeTabIndex - 1
        } else if index == activeTabIndex {
            newActiveTabIndex = min(activeTabIndex, tabs.count - 2)
        } else {
            newActiveTabIndex = activeTabIndex
        }

        tabs[index].webView?.stopLoading()
        tabs[index].webView = nil
        tabs.remove(at: index)
        activeTabIndex = newActiveTabIndex

        let newURL = activeTab?.displayURL ?? ""
        if urlBarText != newURL {
            urlBarText = newURL
        }
        aliasSuggestions = []
    }

    func switchToTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        let oldTab = activeTab
        oldTab?.captureSnapshot()

        activeTabIndex = index
        let newURL = activeTab?.displayURL ?? ""
        if urlBarText != newURL {
            urlBarText = newURL
        }
        presentedSheet = nil
    }

    func navigateTo(_ input: String) {
        guard let tab = activeTab else { return }
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        let url: URL?

        // Check URL aliases first
        if let aliasURL = URLAliasService.resolveAlias(trimmedInput),
           let resolvedURL = URL(string: aliasURL) {
            url = resolvedURL
        } else if trimmedInput.hasPrefix("http://") || trimmedInput.hasPrefix("https://") {
            url = URL(string: trimmedInput)
        } else if trimmedInput.contains(".") && !trimmedInput.contains(" ") {
            url = URL(string: "https://\(trimmedInput)")
        } else {
            let query = trimmedInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedInput
            url = URL(string: searchURL(for: query))
        }

        guard let validURL = url else { return }
        tab.url = validURL
        tab.lastURL = validURL
        urlBarText = validURL.absoluteString
        tab.webView?.load(URLRequest(url: validURL))
        aliasSuggestions = []
    }

    func updateAliasSuggestions() {
        aliasSuggestions = URLAliasService.matchingAliases(for: urlBarText)
    }

    func goBack() {
        activeTab?.webView?.goBack()
    }

    func goForward() {
        activeTab?.webView?.goForward()
    }

    func reload() {
        activeTab?.webView?.reload()
    }

    func updateURLBar() {
        let newValue = activeTab?.webView?.url?.absoluteString ?? activeTab?.displayURL ?? ""
        guard urlBarText != newValue else { return }
        urlBarText = newValue
    }

    // MARK: - Credential Cache (#1)

    func loadMatchingCredentials(for domain: String) {
        let lowDomain = domain.lowercased()

        if let cached = credentialCache[lowDomain] {
            matchingCredentials = cached
            currentRotationIndex = 0
            prefetchPasswords(for: cached)
            return
        }

        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Credential>(
                predicate: #Predicate<Credential> { $0.domain == lowDomain },
                sortBy: [SortDescriptor(\Credential.username)]
            )
            let results = try context.fetch(descriptor)
            credentialCache[lowDomain] = results
            matchingCredentials = results
            currentRotationIndex = 0
            prefetchPasswords(for: results)
        } catch {
            matchingCredentials = []
        }
    }

    func invalidateCredentialCache(for domain: String? = nil) {
        if let domain {
            credentialCache.removeValue(forKey: domain.lowercased())
        } else {
            credentialCache.removeAll()
        }
        passwordCache.removeAll()
    }

    // MARK: - Batch Keychain Reads (#6, #19)

    private func prefetchPasswords(for credentials: [Credential]) {
        let idsToFetch = credentials.map(\.id).filter { passwordCache[$0] == nil }
        guard !idsToFetch.isEmpty else { return }

        let ids = idsToFetch
        Task {
            let passwords = await Task.detached {
                KeychainService.shared.batchGetPasswords(for: ids)
            }.value
            for (id, pass) in passwords {
                self.passwordCache[id] = pass
            }
            self.prewarmNextCredential()
        }
    }

    private func getCachedPassword(for credentialID: String) -> String? {
        if let cached = passwordCache[credentialID] {
            return cached
        }
        let password = KeychainService.shared.getPassword(for: credentialID)
        if let password {
            passwordCache[credentialID] = password
        }
        return password
    }

    // MARK: - Site Setting Cache (#5)

    func fetchSiteSetting(for domain: String) -> SiteSetting? {
        let lowDomain = domain.lowercased()
        if let cached = siteSettingCache[lowDomain] {
            return cached
        }
        if missingSiteSettingDomains.contains(lowDomain) {
            return nil
        }

        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<SiteSetting>(
            predicate: #Predicate<SiteSetting> { $0.domain == lowDomain }
        )
        let result = try? context.fetch(descriptor).first
        if let result {
            siteSettingCache[lowDomain] = result
            missingSiteSettingDomains.remove(lowDomain)
        } else {
            missingSiteSettingDomains.insert(lowDomain)
        }
        return result
    }

    func invalidateSiteSettingCache(for domain: String) {
        let lowDomain = domain.lowercased()
        siteSettingCache.removeValue(forKey: lowDomain)
        missingSiteSettingDomains.remove(lowDomain)
    }

    // MARK: - Pre-warm Next Credential (#16)

    private func prewarmNextCredential() {
        guard matchingCredentials.count > 1 else {
            pendingFillScript = nil
            pendingFillScriptIndex = nil
            return
        }
        // After rotateCredential increments currentRotationIndex, this precomputes
        // the fill script for the current index (which is the next credential to fill).
        let targetIndex = currentRotationIndex
        let targetCredential = matchingCredentials[targetIndex]
        guard let password = passwordCache[targetCredential.id] else {
            pendingFillScript = nil
            pendingFillScriptIndex = nil
            return
        }
        let siteSetting = fetchSiteSetting(for: activeTab?.domain ?? "")
        pendingFillScript = JavaScriptInjectionService.fillCredentialScript(
            username: targetCredential.username,
            password: password,
            usernameSelector: siteSetting?.usernameSelector,
            passwordSelector: siteSetting?.passwordSelector
        )
        pendingFillScriptIndex = targetIndex
    }

    // MARK: - Credential Rotation (RC)

    func rotateCredential() {
        guard !matchingCredentials.isEmpty else {
            showToast("No saved credentials for this site")
            return
        }

        let credential = matchingCredentials[currentRotationIndex]
        let siteSetting = fetchSiteSetting(for: activeTab?.domain ?? "")

        let script: String
        if let pending = pendingFillScript, pendingFillScriptIndex == currentRotationIndex {
            script = pending
            pendingFillScript = nil
            pendingFillScriptIndex = nil
        } else {
            guard let password = getCachedPassword(for: credential.id) else {
                showToast("Password not found in keychain")
                return
            }
            script = JavaScriptInjectionService.fillCredentialScript(
                username: credential.username,
                password: password,
                usernameSelector: siteSetting?.usernameSelector,
                passwordSelector: siteSetting?.passwordSelector
            )
        }

        activeTab?.webView?.evaluateJavaScript(script) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                let total = self.matchingCredentials.count
                let display = self.currentRotationIndex + 1
                self.showToast("Rotated to: \(credential.username) (\(display)/\(total))")

                credential.lastUsedAt = Date()
                credential.usageCount += 1

                self.currentRotationIndex = (self.currentRotationIndex + 1) % total
                self.prewarmNextCredential()

                if siteSetting?.isAutoLoginEnabled == true {
                    self.performAutoLogin(siteSetting: siteSetting)
                }
            }
        }
    }

    func fillCredential(_ credential: Credential) {
        guard let password = getCachedPassword(for: credential.id) else {
            showToast("Password not found")
            return
        }

        let siteSetting = fetchSiteSetting(for: activeTab?.domain ?? "")
        let script = JavaScriptInjectionService.fillCredentialScript(
            username: credential.username,
            password: password,
            usernameSelector: siteSetting?.usernameSelector,
            passwordSelector: siteSetting?.passwordSelector
        )

        activeTab?.webView?.evaluateJavaScript(script) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.showToast("Filled: \(credential.username)")
                credential.lastUsedAt = Date()
                credential.usageCount += 1
                self.presentedSheet = nil

                if siteSetting?.isAutoLoginEnabled == true {
                    self.performAutoLogin(siteSetting: siteSetting)
                }
            }
        }
    }

    // MARK: - Auto Login & Sure Login (#15 structured concurrency)

    func performAutoLogin(siteSetting: SiteSetting?) {
        guard let siteSetting, siteSetting.isAutoLoginEnabled else { return }
        isAutoSubmitting = true

        let script = JavaScriptInjectionService.submitFormScript(
            submitSelector: siteSetting.submitButtonSelector
        )

        activeTab?.webView?.evaluateJavaScript(script) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                if siteSetting.isSureLoginEnabled {
                    self.startSureLogin(siteSetting: siteSetting)
                } else {
                    self.isAutoSubmitting = false
                }
            }
        }
    }

    private func startSureLogin(siteSetting: SiteSetting) {
        sureLoginTask?.cancel()
        sureLoginTask = Task { [weak self] in
            guard let self else { return }
            let retries = siteSetting.sureLoginRetryCount
            let delay = siteSetting.sureLoginDelaySeconds
            let submitSelector = siteSetting.submitButtonSelector

            for _ in 0..<retries {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }

                let script = JavaScriptInjectionService.submitFormScript(submitSelector: submitSelector)
                _ = try? await self.activeTab?.webView?.evaluateJavaScript(script)
            }

            self.isAutoSubmitting = false
        }
    }

    // MARK: - Burn

    func burnCurrentTab() async {
        guard let tab = activeTab else { return }
        let lastURL = tab.lastURL ?? tab.url

        let dataStore = tab.webView?.configuration.websiteDataStore ?? WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let normalizedDomain = tab.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if !normalizedDomain.isEmpty {
            let records = await dataStore.dataRecords(ofTypes: dataTypes)
            let matching = records.filter { record in
                record.displayName.lowercased().contains(normalizedDomain)
            }
            await dataStore.removeData(ofTypes: dataTypes, for: matching)
            if let url = lastURL {
                tab.webView?.load(URLRequest(url: url))
            }
        } else if let url = lastURL {
            tab.webView?.load(URLRequest(url: url))
        }

        if let context = modelContext {
            let domain = tab.domain
            do {
                try context.delete(
                    model: BrowsingHistoryEntry.self,
                    where: #Predicate<BrowsingHistoryEntry> { $0.domain == domain }
                )
                try context.save()
            } catch {}
        }

        showToast("Session burned & reloaded")
    }

    // MARK: - Auto RC + Auto Burn

    func performAutoRC() {
        guard let domain = activeTab?.domain else { return }
        let siteSetting = fetchSiteSetting(for: domain)
        guard siteSetting?.isAutoRCEnabled == true else { return }

        if siteSetting?.isAutoBurnOnRC == true {
            Task {
                await burnCurrentTab()
                rotateCredential()
            }
        } else {
            rotateCredential()
        }
    }

    // MARK: - Debounced History (#7)

    func addHistoryEntry(url: String, title: String) {
        guard url != lastHistoryURL else { return }
        lastHistoryURL = url

        historyDebounceTask?.cancel()
        historyDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled, let self, let context = self.modelContext else { return }
            let domain = CredentialImportService.extractDomain(from: url)
            let entry = BrowsingHistoryEntry(url: url, title: title, domain: domain)
            context.insert(entry)
        }
    }

    func addBookmark() {
        guard let context = modelContext, let tab = activeTab,
              let url = tab.webView?.url?.absoluteString else {
            showToast("Nothing to bookmark")
            return
        }
        let bookmark = Bookmark(url: url, title: tab.title, domain: tab.domain)
        context.insert(bookmark)
        showToast("Bookmark added")
    }

    // MARK: - Form Detection

    func checkForLoginForm() {
        let script = JavaScriptInjectionService.detectLoginFormScript()
        activeTab?.webView?.evaluateJavaScript(script) { [weak self] result, _ in
            Task { @MainActor in
                guard let self, let json = result as? String,
                      let data = json.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let hasForm = dict["hasLoginForm"] as? Bool, hasForm else { return }

                let domain = self.activeTab?.domain ?? ""
                self.loadMatchingCredentials(for: domain)

                if !self.matchingCredentials.isEmpty {
                    let credential = self.matchingCredentials[0]
                    guard let password = self.getCachedPassword(for: credential.id) else { return }
                    let siteSetting = self.fetchSiteSetting(for: domain)
                    let fillScript = JavaScriptInjectionService.fillCredentialScript(
                        username: credential.username,
                        password: password,
                        usernameSelector: siteSetting?.usernameSelector,
                        passwordSelector: siteSetting?.passwordSelector
                    )
                    self.activeTab?.webView?.evaluateJavaScript(fillScript) { _, _ in
                        Task { @MainActor in
                            credential.lastUsedAt = Date()
                            credential.usageCount += 1
                            if siteSetting?.isAutoLoginEnabled == true {
                                self.performAutoLogin(siteSetting: siteSetting)
                            }
                        }
                    }
                }
            }
        }
    }

    func detectAndOfferSave() {
        let script = JavaScriptInjectionService.extractFilledCredentialsScript()
        activeTab?.webView?.evaluateJavaScript(script) { [weak self] result, _ in
            Task { @MainActor in
                guard let self, let json = result as? String,
                      let data = json.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let found = dict["found"] as? Bool, found,
                      let username = dict["username"] as? String, !username.isEmpty,
                      let password = dict["password"] as? String, !password.isEmpty else { return }

                let domain = self.activeTab?.domain ?? ""
                self.loadMatchingCredentials(for: domain)
                let alreadyExists = self.matchingCredentials.contains { $0.username == username }
                if !alreadyExists {
                    self.detectedUsername = username
                    self.detectedPassword = password
                    self.isShowingSaveCredentialAlert = true
                }
            }
        }
    }

    func saveDetectedCredential() {
        guard let context = modelContext, let domain = activeTab?.domain else { return }
        let credential = Credential(domain: domain, username: detectedUsername)

        guard KeychainService.shared.savePassword(detectedPassword, for: credential.id) else {
            showToast("Failed to save credential for \(domain)")
            return
        }

        context.insert(credential)
        passwordCache[credential.id] = detectedPassword
        invalidateCredentialCache(for: domain)
        showToast("Credential saved for \(domain)")
        detectedUsername = ""
        detectedPassword = ""
    }

    // MARK: - Helpers

    func showToast(_ message: String) {
        toastHideTask?.cancel()
        toastMessage = message
        withAnimation(.snappy) { toastVisible = true }
        toastHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { self?.toastVisible = false }
        }
    }

    private func searchURL(for query: String) -> String {
        let engine = UserDefaults.standard.string(forKey: "defaultSearchEngine") ?? "Google"
        switch engine {
        case "DuckDuckGo":
            return "https://duckduckgo.com/?q=\(query)"
        case "Bing":
            return "https://www.bing.com/search?q=\(query)"
        default:
            return "https://www.google.com/search?q=\(query)"
        }
    }
}
