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
        webView.isInspectable = true

        tab.webView = webView
        tab.isWebViewActive = true
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

        init(tab: BrowserTab, viewModel: BrowserViewModel) {
            self.tab = tab
            self.viewModel = viewModel
        }

        nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                tab.isLoading = true
                tab.canGoBack = webView.canGoBack
                tab.canGoForward = webView.canGoForward
            }
        }

        nonisolated func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            Task { @MainActor in
                tab.url = webView.url
                tab.title = webView.title ?? "Loading..."
                tab.canGoBack = webView.canGoBack
                tab.canGoForward = webView.canGoForward
                viewModel.updateURLBar()
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                tab.isLoading = false
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

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                tab.isLoading = false
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                tab.isLoading = false
            }
        }

        nonisolated func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            let navType = await MainActor.run { navigationAction.navigationType }
            if navType == .formSubmitted {
                await MainActor.run {
                    viewModel.detectAndOfferSave()
                }
            }
            return .allow
        }
    }
}
