import SwiftUI
import WebKit

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            HStack(spacing: 8) {
                TextField("Ask me anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || viewModel.isLoading)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = inputText
        inputText = ""
        viewModel.sendMessage(text)
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    FormattedTextView(text: message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(16)
                } else {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }

                if let toolCall = message.toolCall {
                    ToolCallBadge(toolCall: toolCall)
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Formatted Text View (Markdown + LaTeX)
struct FormattedTextView: View {
    let text: String
    @State private var attributedText: AttributedString = AttributedString("")
    @State private var hasLaTeX: Bool = false
    @State private var webViewHeight: CGFloat = 0

    var body: some View {
        if hasLaTeX {
            LaTeXWebView(content: text, height: $webViewHeight)
                .frame(height: max(webViewHeight, 20))
        } else {
            Text(attributedText)
                .textSelection(.enabled)
        }
    }

    init(text: String) {
        self.text = text
        // Check for LaTeX patterns
        let latexPattern = "\\$\\$[\\s\\S]+?\\$\\$|\\$[^\\$]+?\\$|\\\\\\([\\s\\S]+?\\\\\\)|\\\\\\[[\\s\\S]+?\\\\\\]"
        _hasLaTeX = State(initialValue: text.range(of: latexPattern, options: .regularExpression) != nil)
        _attributedText = State(initialValue: FormattedTextView.parseMarkdown(text))
    }

    static func parseMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Process code blocks first (```code```)
        let codeBlockPattern = "```([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text),
                   let attrRange = result.range(of: String(text[range])) {
                    let code = String(text[range]).replacingOccurrences(of: "```", with: "")
                    var codeAttr = AttributedString(code)
                    codeAttr.font = .system(.body, design: .monospaced)
                    codeAttr.backgroundColor = Color(NSColor.quaternaryLabelColor)
                    result.replaceSubrange(attrRange, with: codeAttr)
                }
            }
        }

        // Process inline code (`code`)
        let inlineCodePattern = "`([^`]+)`"
        if let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []) {
            let nsString = String(result.characters) as NSString
            let matches = regex.matches(in: String(result.characters), options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if let range = Range(match.range, in: String(result.characters)),
                   let attrRange = result.range(of: String(String(result.characters)[range])) {
                    let fullMatch = String(String(result.characters)[range])
                    let code = fullMatch.dropFirst().dropLast()
                    var codeAttr = AttributedString(String(code))
                    codeAttr.font = .system(.body, design: .monospaced)
                    codeAttr.backgroundColor = Color(NSColor.quaternaryLabelColor)
                    result.replaceSubrange(attrRange, with: codeAttr)
                }
            }
        }

        // Process bold (**text** or __text__)
        let boldPatterns = ["\\*\\*([^*]+)\\*\\*", "__([^_]+)__"]
        for pattern in boldPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let currentText = String(result.characters)
                let nsString = currentText as NSString
                let matches = regex.matches(in: currentText, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    if match.numberOfRanges >= 2,
                       let fullRange = Range(match.range, in: currentText),
                       let contentRange = Range(match.range(at: 1), in: currentText) {
                        let fullMatch = String(currentText[fullRange])
                        if let attrRange = result.range(of: fullMatch) {
                            var boldAttr = AttributedString(String(currentText[contentRange]))
                            boldAttr.font = .body.bold()
                            result.replaceSubrange(attrRange, with: boldAttr)
                        }
                    }
                }
            }
        }

        // Process italic (*text* or _text_) - be careful not to match inside words
        let italicPatterns = ["(?<![*])\\*([^*]+)\\*(?![*])", "(?<![_])_([^_]+)_(?![_])"]
        for pattern in italicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let currentText = String(result.characters)
                let nsString = currentText as NSString
                let matches = regex.matches(in: currentText, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    if match.numberOfRanges >= 2,
                       let fullRange = Range(match.range, in: currentText),
                       let contentRange = Range(match.range(at: 1), in: currentText) {
                        let fullMatch = String(currentText[fullRange])
                        if let attrRange = result.range(of: fullMatch) {
                            var italicAttr = AttributedString(String(currentText[contentRange]))
                            italicAttr.font = .body.italic()
                            result.replaceSubrange(attrRange, with: italicAttr)
                        }
                    }
                }
            }
        }

        // Process highlights (==text==)
        let highlightPattern = "==([^=]+)=="
        if let regex = try? NSRegularExpression(pattern: highlightPattern, options: []) {
            let currentText = String(result.characters)
            let nsString = currentText as NSString
            let matches = regex.matches(in: currentText, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 2,
                   let fullRange = Range(match.range, in: currentText),
                   let contentRange = Range(match.range(at: 1), in: currentText) {
                    let fullMatch = String(currentText[fullRange])
                    if let attrRange = result.range(of: fullMatch) {
                        var highlightAttr = AttributedString(String(currentText[contentRange]))
                        highlightAttr.backgroundColor = Color.yellow.opacity(0.4)
                        result.replaceSubrange(attrRange, with: highlightAttr)
                    }
                }
            }
        }

        // Process underline (<u>text</u> or ++text++)
        let underlinePatterns = ["<u>([^<]+)</u>", "\\+\\+([^+]+)\\+\\+"]
        for pattern in underlinePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let currentText = String(result.characters)
                let nsString = currentText as NSString
                let matches = regex.matches(in: currentText, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    if match.numberOfRanges >= 2,
                       let fullRange = Range(match.range, in: currentText),
                       let contentRange = Range(match.range(at: 1), in: currentText) {
                        let fullMatch = String(currentText[fullRange])
                        if let attrRange = result.range(of: fullMatch) {
                            var underlineAttr = AttributedString(String(currentText[contentRange]))
                            underlineAttr.underlineStyle = .single
                            result.replaceSubrange(attrRange, with: underlineAttr)
                        }
                    }
                }
            }
        }

        // Process strikethrough (~~text~~)
        let strikePattern = "~~([^~]+)~~"
        if let regex = try? NSRegularExpression(pattern: strikePattern, options: []) {
            let currentText = String(result.characters)
            let nsString = currentText as NSString
            let matches = regex.matches(in: currentText, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 2,
                   let fullRange = Range(match.range, in: currentText),
                   let contentRange = Range(match.range(at: 1), in: currentText) {
                    let fullMatch = String(currentText[fullRange])
                    if let attrRange = result.range(of: fullMatch) {
                        var strikeAttr = AttributedString(String(currentText[contentRange]))
                        strikeAttr.strikethroughStyle = .single
                        result.replaceSubrange(attrRange, with: strikeAttr)
                    }
                }
            }
        }

        return result
    }
}

// MARK: - LaTeX Web View
struct LaTeXWebView: NSViewRepresentable {
    let content: String
    @Binding var height: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(content: content)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func generateHTML(content: String) -> String {
        // Escape HTML but preserve LaTeX
        let escaped = content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Convert markdown to HTML
        var html = escaped
        // Bold
        html = html.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "__([^_]+)__", with: "<strong>$1</strong>", options: .regularExpression)
        // Italic
        html = html.replacingOccurrences(of: "(?<![*])\\*([^*]+)\\*(?![*])", with: "<em>$1</em>", options: .regularExpression)
        // Code
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        // Highlight
        html = html.replacingOccurrences(of: "==([^=]+)==", with: "<mark>$1</mark>", options: .regularExpression)
        // Underline
        html = html.replacingOccurrences(of: "\\+\\+([^+]+)\\+\\+", with: "<u>$1</u>", options: .regularExpression)
        // Strikethrough
        html = html.replacingOccurrences(of: "~~([^~]+)~~", with: "<del>$1</del>", options: .regularExpression)
        // Line breaks
        html = html.replacingOccurrences(of: "\n", with: "<br>")

        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor = isDarkMode ? "#FFFFFF" : "#000000"
        let bgColor = isDarkMode ? "transparent" : "transparent"
        let codeBg = isDarkMode ? "#3a3a3c" : "#e5e5e7"

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    font-size: 13px;
                    line-height: 1.5;
                    color: \(textColor);
                    background: \(bgColor);
                    margin: 0;
                    padding: 0;
                }
                code {
                    font-family: 'SF Mono', Menlo, monospace;
                    background: \(codeBg);
                    padding: 2px 4px;
                    border-radius: 4px;
                    font-size: 12px;
                }
                mark {
                    background: rgba(255, 255, 0, 0.4);
                    padding: 1px 2px;
                    border-radius: 2px;
                }
                .MathJax {
                    font-size: 100% !important;
                }
            </style>
            <script>
                window.MathJax = {
                    tex: {
                        inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                        displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']]
                    },
                    startup: {
                        ready: () => {
                            MathJax.startup.defaultReady();
                            MathJax.startup.promise.then(() => {
                                const height = document.body.scrollHeight;
                                window.webkit.messageHandlers.heightChanged.postMessage(height);
                            });
                        }
                    }
                };
            </script>
        </head>
        <body>\(html)</body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LaTeXWebView

        init(_ parent: LaTeXWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self?.parent.height = height + 10
                    }
                }
            }
        }
    }
}

// MARK: - Tool Call Badge
struct ToolCallBadge: View {
    let toolCall: ToolCall

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: toolCall.icon)
            Text(toolCall.displayName)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animationOffset
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .onAppear {
            animationOffset = -5
        }
    }
}

// MARK: - View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false

    private let aiService = AIService.shared

    init() {
        // Welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi! I'm your AI assistant. I can help you manage your calendar, send emails, and more. What would you like to do?"
        ))
    }

    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isLoading = true

        Task {
            do {
                let response = try await aiService.sendMessage(text, conversationHistory: messages)

                await MainActor.run {
                    isLoading = false
                    messages.append(response)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    messages.append(ChatMessage(
                        role: .assistant,
                        content: "Sorry, I encountered an error: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }
}

// MARK: - Models
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    var toolCall: ToolCall?

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, toolCall: ToolCall? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCall = toolCall
    }
}

struct ToolCall: Codable {
    let name: String
    let parameters: [String: String]

    var displayName: String {
        switch name {
        case "create_calendar_event": return "Creating event"
        case "list_calendar_events": return "Listing events"
        case "send_email": return "Sending email"
        case "draft_email": return "Drafting email"
        case "search_emails": return "Searching emails"
        default: return name
        }
    }

    var icon: String {
        switch name {
        case "create_calendar_event", "list_calendar_events": return "calendar"
        case "send_email", "draft_email", "search_emails": return "envelope"
        default: return "gear"
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 400, height: 400)
}
