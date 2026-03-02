import SwiftUI
import WebKit

// MARK: - Markdown WebView (WKWebView with GitHub-like CSS)

/// WKWebView wrapper that renders markdown as HTML with GitHub-like styling.
/// Automatically adapts to dark/light mode. Dynamically sizes to content height.
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NoScrollWKWebView {
        let config = WKWebViewConfiguration()
        let wv = NoScrollWKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        return wv
    }

    func updateNSView(_ wv: NoScrollWKWebView, context: Context) {
        wv.loadHTMLString(buildHTML(), baseURL: nil)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        init(_ parent: MarkdownWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                DispatchQueue.main.async {
                    if let h = result as? Double, h > 0 {
                        self.parent.height = CGFloat(h)
                    }
                }
            }
        }
    }

    // MARK: - HTML

    private func buildHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>\(Self.githubCSS)</style>
        </head>
        <body>\(renderMarkdown(markdown))</body>
        </html>
        """
    }

    // MARK: - GitHub-inspired CSS

    static let githubCSS = """
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            font-size: 14px; line-height: 1.6; color: #1f2328;
            background: transparent; word-wrap: break-word;
        }
        a { color: #0969da; text-decoration: none; }
        a:hover { text-decoration: underline; }
        h1,h2,h3,h4,h5,h6 { margin-top:24px; margin-bottom:16px; font-weight:600; line-height:1.25; }
        h1 { font-size:2em; padding-bottom:.3em; border-bottom:1px solid #d8dee4; }
        h2 { font-size:1.5em; padding-bottom:.3em; border-bottom:1px solid #d8dee4; }
        h3 { font-size:1.25em; }
        h4 { font-size:1em; }
        h5 { font-size:.875em; }
        h6 { font-size:.85em; color:#636c76; }
        h1:first-child { margin-top:0; }
        p { margin-bottom:16px; }
        strong { font-weight:600; }
        code {
            font-family:"SF Mono",ui-monospace,Menlo,monospace;
            font-size:85%; padding:.2em .4em;
            background:rgba(175,184,193,.2); border-radius:6px;
        }
        pre {
            padding:16px; overflow:auto; font-size:85%; line-height:1.45;
            background:#f6f8fa; border-radius:6px; margin-bottom:16px;
        }
        pre code { background:none; padding:0; border-radius:0; font-size:100%; }
        blockquote {
            margin-bottom:16px; padding:0 1em; color:#636c76;
            border-left:.25em solid #d8dee4;
        }
        ul,ol { padding-left:2em; margin-bottom:16px; }
        li { margin:.25em 0; }
        li>ul,li>ol { margin:0; margin-top:.25em; }
        img { max-width:100%; height:auto; border-radius:6px; }
        hr { height:.25em; background-color:#d8dee4; border:0; border-radius:3px; margin:24px 0; }
        table { border-spacing:0; border-collapse:collapse; margin-bottom:16px; display:block; width:max-content; max-width:100%; overflow:auto; }
        table th { font-weight:600; }
        table td,table th { padding:6px 13px; border:1px solid #d8dee4; }
        table tr:nth-child(2n) { background-color:#f6f8fa; }
        del { text-decoration:line-through; }
        @media (prefers-color-scheme: dark) {
            body { color:#e6edf3; }
            a { color:#4493f8; }
            code { background:rgba(110,118,129,.4); color:#e6edf3; }
            pre { background:#161b22; color:#e6edf3; }
            blockquote { border-left-color:#3d444d; color:#9198a1; }
            h1,h2 { border-bottom-color:#21262d; }
            h6 { color:#9198a1; }
            hr { background-color:#21262d; }
            table td,table th { border-color:#3d444d; }
            table tr:nth-child(2n) { background-color:#161b22; }
        }
    """

    // MARK: - Markdown → HTML renderer

    private func renderMarkdown(_ input: String) -> String {
        let lines = input.components(separatedBy: "\n")
        var html = ""
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let fence = line.hasPrefix("```") ? "```" : "~~~"
                let lang  = String(line.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix(fence) {
                    code.append(lines[i])
                    i += 1
                }
                let escaped = code.joined(separator: "\n").htmlEscaped
                let cls = lang.isEmpty ? "" : " class=\"language-\(lang)\""
                html += "<pre><code\(cls)>\(escaped)</code></pre>\n"
                i += 1
                continue
            }

            // ATX header
            if let h = parseATXHeader(line) { html += h + "\n"; i += 1; continue }

            // Setext header
            if i + 1 < lines.count {
                let next = lines[i + 1]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    if next.count >= 2 && next.allSatisfy({ $0 == "=" }) {
                        html += "<h1>\(inline(line))</h1>\n"; i += 2; continue
                    }
                    if next.count >= 2 && next.allSatisfy({ $0 == "-" }) {
                        html += "<h2>\(inline(line))</h2>\n"; i += 2; continue
                    }
                }
            }

            // Horizontal rule
            let stripped = line.filter { !$0.isWhitespace }
            if stripped.count >= 3 &&
               (stripped.allSatisfy({ $0 == "-" }) ||
                stripped.allSatisfy({ $0 == "*" }) ||
                stripped.allSatisfy({ $0 == "_" })) {
                html += "<hr>\n"; i += 1; continue
            }

            // Blockquote
            if line.hasPrefix("> ") || line == ">" {
                var bq: [String] = []
                while i < lines.count && (lines[i].hasPrefix("> ") || lines[i] == ">") {
                    bq.append(String(lines[i].dropFirst(lines[i].hasPrefix("> ") ? 2 : 1)))
                    i += 1
                }
                html += "<blockquote>\(renderMarkdown(bq.joined(separator: "\n")))</blockquote>\n"
                continue
            }

            // Unordered list
            if isULBullet(line) {
                var items: [String] = []
                while i < lines.count && isULBullet(lines[i]) {
                    items.append("<li>\(inline(String(lines[i].dropFirst(2))))</li>")
                    i += 1
                }
                html += "<ul>\n\(items.joined(separator: "\n"))\n</ul>\n"
                continue
            }

            // Ordered list
            if let _ = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                var items: [String] = []
                while i < lines.count,
                      let r = lines[i].range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    items.append("<li>\(inline(String(lines[i][r.upperBound...])))</li>")
                    i += 1
                }
                html += "<ol>\n\(items.joined(separator: "\n"))\n</ol>\n"
                continue
            }

            // Table
            if line.contains("|"), i + 1 < lines.count {
                let sep = lines[i + 1]
                if sep.contains("|") && sep.contains("-") {
                    let headers = tableCells(line)
                    i += 2
                    var rows: [[String]] = []
                    while i < lines.count && lines[i].contains("|") {
                        rows.append(tableCells(lines[i])); i += 1
                    }
                    var t = "<table>\n<thead><tr>"
                    headers.forEach { t += "<th>\(inline($0))</th>" }
                    t += "</tr></thead>\n<tbody>"
                    rows.forEach { row in
                        t += "<tr>"
                        row.forEach { t += "<td>\(inline($0))</td>" }
                        t += "</tr>"
                    }
                    t += "</tbody></table>\n"
                    html += t
                    continue
                }
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty { i += 1; continue }

            // Paragraph
            html += "<p>\(inline(line))</p>\n"
            i += 1
        }

        return html
    }

    private func parseATXHeader(_ line: String) -> String? {
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level)
            if line.hasPrefix(prefix + " ") {
                let text = String(line.dropFirst(level + 1))
                return "<h\(level)>\(inline(text))</h\(level)>"
            } else if line == prefix {
                return "<h\(level)></h\(level)>"
            }
        }
        return nil
    }

    private func isULBullet(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private func tableCells(_ line: String) -> [String] {
        var s = line
        if s.hasPrefix("|") { s = String(s.dropFirst()) }
        if s.hasSuffix("|") { s = String(s.dropLast()) }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Processes inline markdown (bold, italic, code, links, images, strikethrough).
    private func inline(_ raw: String) -> String {
        var s = raw.htmlEscaped
        // Images before links
        s = s.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^\)]+)\)"#,
            with: "<img alt=\"$1\" src=\"$2\">",
            options: .regularExpression
        )
        // Links
        s = s.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^\)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )
        // Bold + italic
        s = s.replacingOccurrences(of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"___(.+?)___"#,       with: "<strong><em>$1</em></strong>", options: .regularExpression)
        // Bold
        s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"__(.+?)__"#,     with: "<strong>$1</strong>", options: .regularExpression)
        // Italic
        s = s.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"_([^_]+)_"#,  with: "<em>$1</em>", options: .regularExpression)
        // Strikethrough
        s = s.replacingOccurrences(of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression)
        // Inline code
        s = s.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        return s
    }
}

// MARK: - WKWebView subclass that forwards scroll to parent

/// Prevents WKWebView from consuming scroll events so the parent SwiftUI ScrollView handles them.
class NoScrollWKWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

// MARK: - HTML Escape

private extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
