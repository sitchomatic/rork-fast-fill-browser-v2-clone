import SwiftUI
import SwiftData

struct BrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BrowserViewModel()
    @State private var biometricService: BiometricService
    @FocusState private var isURLBarFocused: Bool

    init(biometricService: BiometricService) {
        _biometricService = State(initialValue: biometricService)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                urlBar
                aliasSuggestions
                progressBar
                webContent
                bottomToolbar
            }

            if viewModel.toastVisible, let message = viewModel.toastMessage {
                ToastView(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 70)
                    .zIndex(100)
            }
        }
        .task {
            viewModel.setup(modelContext: modelContext)
            await WebViewConfigurationFactory.shared.prepare()
            DNSPrewarmService.shared.prewarmTopDomains(modelContext: modelContext)
        }
        .sheet(item: $viewModel.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert("Save Login?", isPresented: $viewModel.isShowingSaveCredentialAlert) {
            Button("Save") { viewModel.saveDetectedCredential() }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Save credentials for \(viewModel.activeTab?.domain ?? "this site")?\nUsername: \(viewModel.detectedUsername)")
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: PresentedSheet) -> some View {
        switch sheet {
        case .tabs:
            TabManagerView(viewModel: viewModel)
        case .credentialPicker:
            CredentialPickerSheet(viewModel: viewModel)
        case .vault:
            NavigationStack { VaultView() }
        case .siteSettings(let domain):
            NavigationStack { SiteSettingsView(domain: domain) }
        case .settings:
            NavigationStack { AppSettingsView(biometricService: biometricService) }
        case .bookmarks:
            NavigationStack { BookmarksView(viewModel: viewModel) }
        case .history:
            NavigationStack { HistoryView(viewModel: viewModel) }
        case .urlAliases:
            NavigationStack { URLAliasListView(viewModel: viewModel) }
        }
    }

    private var urlBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(viewModel.activeTab?.url?.scheme == "https" ? .green : .secondary)

            TextField("Search, enter URL, or alias shortcut", text: $viewModel.urlBarText)
                .textFieldStyle(.plain)
                .font(.callout)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.go)
                .focused($isURLBarFocused)
                .onSubmit {
                    viewModel.navigateTo(viewModel.urlBarText)
                    isURLBarFocused = false
                }
                .onChange(of: viewModel.urlBarText) { _, _ in
                    if isURLBarFocused {
                        viewModel.updateAliasSuggestions()
                    }
                }

            if viewModel.activeTab?.isLoading == true {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Menu {
                Button("Site Settings", systemImage: "gearshape") {
                    if let domain = viewModel.activeTab?.domain, !domain.isEmpty {
                        viewModel.presentedSheet = .siteSettings(domain)
                    }
                }
                Button("Add Bookmark", systemImage: "bookmark") {
                    viewModel.addBookmark()
                }
                Button("URL Aliases", systemImage: "link.badge.plus") {
                    viewModel.presentedSheet = .urlAliases
                }
                Button("Share", systemImage: "square.and.arrow.up") {}
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var aliasSuggestions: some View {
        if isURLBarFocused && !viewModel.aliasSuggestions.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.aliasSuggestions) { alias in
                        Button {
                            viewModel.navigateTo(alias.shortcut)
                            isURLBarFocused = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)

                                Text(alias.shortcut)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(alias.url)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 36)
                    }
                }
            }
            .frame(maxHeight: 160)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 8))
            .padding(.horizontal, 12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            if viewModel.activeTab?.isLoading == true {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(
                        width: geo.size.width * (viewModel.activeTab?.estimatedProgress ?? 0),
                        height: 2
                    )
                    .animation(.linear, value: viewModel.activeTab?.estimatedProgress)
            }
        }
        .frame(height: 2)
    }

    private var webContent: some View {
        ZStack {
            if let tab = viewModel.activeTab {
                WebViewWrapper(tab: tab, viewModel: viewModel)
                    .id(tab.id)
            } else {
                newTabPage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var newTabPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.linearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Fast Fill Browser")
                .font(.title2.bold())

            Text("The smartest login browser")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "chevron.left", disabled: viewModel.activeTab?.canGoBack != true) {
                viewModel.goBack()
            }

            toolbarButton(icon: "chevron.right", disabled: viewModel.activeTab?.canGoForward != true) {
                viewModel.goForward()
            }

            rcButton

            toolbarButton(icon: "flame.fill", tint: .red) {
                viewModel.burnCurrentTab()
            }

            toolbarButton(icon: "key.fill") {
                let domain = viewModel.activeTab?.domain ?? ""
                viewModel.loadMatchingCredentials(for: domain)
                viewModel.presentedSheet = .credentialPicker
            }

            moreMenu
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var rcButton: some View {
        Button {
            let domain = viewModel.activeTab?.domain ?? ""
            viewModel.loadMatchingCredentials(for: domain)
            viewModel.rotateCredential()
        } label: {
            ZStack {
                Circle()
                    .fill(.linearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)

                Text("RC")
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.currentRotationIndex)
        .frame(maxWidth: .infinity)
    }

    private var moreMenu: some View {
        Menu {
            Button("Tabs (\(viewModel.tabs.count))", systemImage: "square.on.square") {
                viewModel.presentedSheet = .tabs
            }
            Button("Bookmarks", systemImage: "bookmark") {
                viewModel.presentedSheet = .bookmarks
            }
            Button("History", systemImage: "clock") {
                viewModel.presentedSheet = .history
            }
            Divider()
            Button("URL Aliases", systemImage: "link.badge.plus") {
                viewModel.presentedSheet = .urlAliases
            }
            Button("Vault", systemImage: "lock.shield") {
                viewModel.presentedSheet = .vault
            }
            Button("Settings", systemImage: "gear") {
                viewModel.presentedSheet = .settings
            }
            Divider()
            Button("New Tab", systemImage: "plus") {
                viewModel.addNewTab()
            }
            Button("Reload", systemImage: "arrow.clockwise") {
                viewModel.reload()
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
    }

    private func toolbarButton(
        icon: String,
        disabled: Bool = false,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(tint ?? .primary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(disabled)
        .frame(maxWidth: .infinity)
    }
}
