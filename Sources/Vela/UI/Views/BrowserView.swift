import SwiftUI
import WebKit

// MARK: - WKWebView wrapper for SwiftUI

struct BrowserView: NSViewRepresentable {
    @Binding var urlString: String
    let onTitleChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        load(webView, urlString: urlString)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let current = webView.url?.absoluteString, current != urlString {
            load(webView, urlString: urlString)
        }
    }

    private func load(_ webView: WKWebView, urlString: String) {
        let cleaned = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
        guard let url = URL(string: cleaned) else { return }
        webView.load(URLRequest(url: url))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: BrowserView
        weak var webView: WKWebView?

        init(_ parent: BrowserView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let title = webView.title, !title.isEmpty {
                parent.onTitleChange(title)
            }
            if let url = webView.url?.absoluteString {
                parent.urlString = url
            }
        }
    }
}

// MARK: - Full Browser Panel

struct BrowserPanel: View {
    @State private var urlString: String
    @State private var inputURL: String
    @State private var pageTitle: String = ""
    @State private var isEditing: Bool = false

    init(initialURL: String = "https://www.google.com") {
        _urlString = State(initialValue: initialURL)
        _inputURL  = State(initialValue: initialURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Address Bar
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))

                TextField("URL ou pesquisa…", text: $inputURL, onCommit: {
                    navigate()
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onTapGesture { isEditing = true }

                if !inputURL.isEmpty {
                    Button { inputURL = ""; isEditing = true } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            BrowserView(urlString: $urlString, onTitleChange: { title in
                pageTitle = title
                if !isEditing { inputURL = urlString }
            })
        }
    }

    private func navigate() {
        isEditing = false
        var target = inputURL.trimmingCharacters(in: .whitespaces)
        if !target.contains(".") || target.contains(" ") {
            // Treat as search
            let query = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? target
            target = "https://www.google.com/search?q=\(query)"
        } else if !target.hasPrefix("http") {
            target = "https://\(target)"
        }
        urlString = target
        inputURL  = target
    }
}
