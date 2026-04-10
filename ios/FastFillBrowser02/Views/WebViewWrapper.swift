import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let tab: BrowserTab
    let viewModel: BrowserViewModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WebViewConfigurationFactory.shared.makeConfiguration()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        webView.isInspectable = true
        #endif

        tab.webView = webView
        tab.isWebViewActive = true
        context.coordinator.observeProgress(of: webView)
        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if tab.webView !== webView {
            tab.webView = webView
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let tab: BrowserTab
        let viewModel: BrowserViewModel
        private var progressObservation: NSKeyValueObservation?

        init(tab: BrowserTab, viewModel: BrowserViewModel) {
            self.tab = tab
            self.viewModel = viewModel
        }

        deinit {
            progressObservation?.invalidate()
        }

        func observeProgress(of webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    self?.tab.estimatedProgress = webView.estimatedProgress
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                tab.isLoading = true
                tab.estimatedProgress = 0
                tab.canGoBack = webView.canGoBack
                tab.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            Task { @MainActor in
                tab.url = webView.url
                tab.title = webView.title ?? "Loading..."
                tab.canGoBack = webView.canGoBack
                tab.canGoForward = webView.canGoForward
                viewModel.updateURLBar()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                tab.isLoading = false
                tab.estimatedProgress = 1
                tab.url = webView.url
                tab.title = webView.title ?? tab.domain
                tab.canGoBack = webView.canGoBack
                tab.canGoForward = webView.canGoForward
                viewModel.updateURLBar()

                if let url = webView.url?.absoluteString {
                    viewModel.addHistoryEntry(url: url, title: tab.title)
                }

                viewModel.checkForLoginForm()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                tab.isLoading = false
                tab.estimatedProgress = 0
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                tab.isLoading = false
                tab.estimatedProgress = 0
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .formSubmitted {
                await MainActor.run {
                    viewModel.detectAndOfferSave()
                }
            }
            return .allow
        }
    }
}
