import WebKit

@MainActor
final class WebViewConfigurationFactory {
    static let shared = WebViewConfigurationFactory()
    
    private(set) var contentRuleList: WKContentRuleList?
    private(set) var isReady: Bool = false

    private init() {}

    func prepare() async {
        await compileContentRules()
        isReady = true
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let detectScript = WKUserScript(
            source: JavaScriptInjectionService.detectLoginFormScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(detectScript)

        let helperScript = WKUserScript(
            source: JavaScriptInjectionService.fillHelperScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(helperScript)

        if let ruleList = contentRuleList {
            config.userContentController.add(ruleList)
        }

        return config
    }

    private func compileContentRules() async {
        let rules = """
        [
            {"trigger":{"url-filter":".*","resource-type":["script"],"url-filter-is-case-sensitive":false,"if-domain":["*doubleclick.net","*googlesyndication.com","*googleadservices.com","*google-analytics.com","*facebook.net","*facebook.com/tr","*analytics.google.com"]},"action":{"type":"block"}},
            {"trigger":{"url-filter":".*","resource-type":["script","image","raw"],"url-filter-is-case-sensitive":false,"if-domain":["*hotjar.com","*mixpanel.com","*segment.io","*amplitude.com","*optimizely.com","*crazyegg.com","*mouseflow.com","*fullstory.com"]},"action":{"type":"block"}},
            {"trigger":{"url-filter":".*\\\\.ads\\\\..*"},"action":{"type":"block"}},
            {"trigger":{"url-filter":".*track(ing|er).*","resource-type":["script","raw"]},"action":{"type":"block"}}
        ]
        """

        do {
            contentRuleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "FastFillBlocker",
                encodedContentRuleList: rules
            )
        } catch {}
    }
}
