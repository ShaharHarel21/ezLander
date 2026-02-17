import SwiftUI
import WebKit

struct EmailView: View {
    @StateObject private var viewModel = EmailViewModel.shared
    @State private var selectedEmail: Email?
    @State private var showingCompose = false
    @State private var showingReply = false
    @State private var replyToEmail: Email?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            emailHeader

            Divider()

            // Content
            if !viewModel.isConnected {
                notConnectedView
            } else if viewModel.isLoading && viewModel.emails.isEmpty {
                loadingView
            } else if let selected = selectedEmail {
                emailDetailView(email: selected)
            } else {
                emailListView
            }
        }
        .sheet(isPresented: $showingCompose) {
            ComposeEmailView(
                onSend: { email in
                    viewModel.sendEmail(email)
                    showingCompose = false
                },
                onCancel: {
                    showingCompose = false
                }
            )
        }
        .sheet(isPresented: $showingReply) {
            if let email = replyToEmail {
                ReplyEmailView(
                    originalEmail: email,
                    onSend: { replyBody in
                        viewModel.replyToEmail(email, body: replyBody)
                        showingReply = false
                        replyToEmail = nil
                    },
                    onCancel: {
                        showingReply = false
                        replyToEmail = nil
                    }
                )
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Header
    private var emailHeader: some View {
        HStack {
            if selectedEmail != nil {
                Button(action: { selectedEmail = nil }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
            }

            Text(selectedEmail != nil ? "Email" : "Inbox")
                .font(.headline)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Button(action: { showingCompose = true }) {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderless)
            .help("Compose")

            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Not Connected View
    private var notConnectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Gmail not connected")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Connect your Gmail account to view and manage your emails")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Connect Gmail") {
                viewModel.connect()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading emails...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Email List View
    private var emailListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.emails) { email in
                    EmailListRow(
                        email: email,
                        onTap: {
                            selectedEmail = email
                            viewModel.markAsRead(email)
                        },
                        onArchive: {
                            viewModel.archiveEmail(email)
                        },
                        onDelete: {
                            viewModel.deleteEmail(email)
                        }
                    )
                    Divider()
                        .padding(.leading, 50)
                }

                if viewModel.emails.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No emails")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
        }
    }

    // MARK: - Email Detail View
    private func emailDetailView(email: Email) -> some View {
        VStack(spacing: 0) {
            // Email header info
            VStack(alignment: .leading, spacing: 8) {
                Text(email.subject)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    // Sender avatar
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(email.senderName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(email.senderName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(email.senderEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(email.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Email body
            if viewModel.loadingEmailId == email.id {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HTMLEmailBodyView(
                    htmlContent: viewModel.fullEmailHtml,
                    plainContent: viewModel.fullEmailBody ?? email.body
                )
            }

            Divider()

            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    replyToEmail = email
                    showingReply = true
                }) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    viewModel.archiveEmail(email)
                    selectedEmail = nil
                }) {
                    Label("Archive", systemImage: "archivebox")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: {
                    viewModel.deleteEmail(email)
                    selectedEmail = nil
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            viewModel.loadFullEmail(email)
        }
    }
}

// MARK: - Email List Row
struct EmailListRow: View {
    let email: Email
    let onTap: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Sender avatar
            Circle()
                .fill(email.isRead ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(email.senderName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(email.isRead ? .secondary : .accentColor)
                )

            // Email content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(email.senderName)
                        .font(.subheadline)
                        .fontWeight(email.isRead ? .regular : .semibold)
                        .lineLimit(1)

                    Spacer()

                    Text(email.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(email.subject)
                    .font(.subheadline)
                    .foregroundColor(email.isRead ? .secondary : .primary)
                    .lineLimit(1)

                Text(email.snippet)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Quick actions on hover
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onArchive) {
                        Image(systemName: "archivebox")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Archive")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Compose Email View
struct ComposeEmailView: View {
    let onSend: (Email) -> Void
    let onCancel: () -> Void

    @State private var toField: String = ""
    @State private var subjectField: String = ""
    @State private var bodyField: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("New Email")
                    .font(.headline)

                Spacer()

                Button("Send") {
                    let email = Email(
                        id: UUID().uuidString,
                        to: toField,
                        subject: subjectField,
                        body: bodyField,
                        date: Date()
                    )
                    onSend(email)
                }
                .buttonStyle(.borderedProminent)
                .disabled(toField.isEmpty || subjectField.isEmpty)
            }
            .padding()

            Divider()

            // Form
            VStack(spacing: 0) {
                HStack {
                    Text("To:")
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("recipient@email.com", text: $toField)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                HStack {
                    Text("Subject:")
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("Email subject", text: $subjectField)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                TextEditor(text: $bodyField)
                    .font(.body)
                    .padding(8)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 380, height: 400)
    }
}

// MARK: - Reply Email View
struct ReplyEmailView: View {
    let originalEmail: Email
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var replyBody: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("Reply")
                    .font(.headline)

                Spacer()

                Button("Send") {
                    onSend(replyBody)
                }
                .buttonStyle(.borderedProminent)
                .disabled(replyBody.isEmpty)
            }
            .padding()

            Divider()

            // Reply form
            VStack(spacing: 0) {
                HStack {
                    Text("To:")
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text(originalEmail.senderName)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                HStack {
                    Text("Subject:")
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    Text("Re: \(originalEmail.subject)")
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                TextEditor(text: $replyBody)
                    .font(.body)
                    .padding(8)

                Divider()

                // Original message preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("On \(originalEmail.formattedDate), \(originalEmail.senderName) wrote:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(originalEmail.body.prefix(200) + (originalEmail.body.count > 200 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(width: 380, height: 450)
    }
}

// MARK: - HTML Email Body View
struct HTMLEmailBodyView: NSViewRepresentable {
    let htmlContent: String?
    let plainContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let content = htmlContent ?? plainContent
        let isHTML = htmlContent != nil && htmlContent!.contains("<")

        if isHTML {
            let styledHTML = wrapHTMLContent(content)
            webView.loadHTMLString(styledHTML, baseURL: nil)
        } else {
            // Convert plain text to simple HTML
            let escapedText = content
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\n", with: "<br>")

            let plainHTML = wrapHTMLContent("<p>\(escapedText)</p>")
            webView.loadHTMLString(plainHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func wrapHTMLContent(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    color: #333;
                    padding: 12px;
                    margin: 0;
                    background: transparent;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #e0e0e0;
                    }
                    a {
                        color: #6bb3f8;
                    }
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                a {
                    color: #0066cc;
                }
                blockquote {
                    border-left: 3px solid #ccc;
                    margin: 10px 0;
                    padding-left: 12px;
                    color: #666;
                }
                pre, code {
                    background: #f5f5f5;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 13px;
                }
                @media (prefers-color-scheme: dark) {
                    pre, code {
                        background: #2d2d2d;
                    }
                    blockquote {
                        border-left-color: #555;
                        color: #aaa;
                    }
                }
                table {
                    border-collapse: collapse;
                    max-width: 100%;
                }
                td, th {
                    padding: 6px 12px;
                    border: 1px solid #ddd;
                }
                @media (prefers-color-scheme: dark) {
                    td, th {
                        border-color: #444;
                    }
                }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Open links in default browser
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - View Model
class EmailViewModel: ObservableObject {
    static let shared = EmailViewModel()

    @Published var emails: [Email] = []
    @Published var isLoading = false
    @Published var isConnected = false
    @Published var error: String?
    @Published var loadingEmailId: String?
    @Published var fullEmailBody: String?
    @Published var fullEmailHtml: String?

    private var hasLoadedOnce = false

    init() {
        checkConnection()
    }

    func onAppear() {
        checkConnection()
        if isConnected && !hasLoadedOnce {
            loadEmails()
        }
    }

    func checkConnection() {
        isConnected = OAuthService.shared.isSignedInWithGoogle
    }

    func connect() {
        Task {
            do {
                try await GmailService.shared.authorize()
                await MainActor.run {
                    isConnected = true
                    loadEmails()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func loadEmails() {
        guard isConnected else { return }

        isLoading = true
        hasLoadedOnce = true

        Task {
            do {
                let fetchedEmails = try await GmailService.shared.listRecentEmails(maxResults: 20)
                await MainActor.run {
                    self.emails = fetchedEmails
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func loadFullEmail(_ email: Email) {
        loadingEmailId = email.id
        fullEmailBody = nil
        fullEmailHtml = nil

        Task {
            do {
                let (plainBody, htmlBody) = try await GmailService.shared.getFullEmailWithHtml(id: email.id)
                await MainActor.run {
                    self.fullEmailBody = plainBody
                    self.fullEmailHtml = htmlBody
                    self.loadingEmailId = nil
                }
            } catch {
                await MainActor.run {
                    self.fullEmailBody = email.body
                    self.fullEmailHtml = nil
                    self.loadingEmailId = nil
                }
            }
        }
    }

    func refresh() {
        checkConnection()
        if isConnected {
            loadEmails()
        }
    }

    func deleteEmail(_ email: Email) {
        Task {
            do {
                try await GmailService.shared.deleteEmail(id: email.id)
                await MainActor.run {
                    self.emails.removeAll { $0.id == email.id }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func archiveEmail(_ email: Email) {
        Task {
            do {
                try await GmailService.shared.archiveEmail(id: email.id)
                await MainActor.run {
                    self.emails.removeAll { $0.id == email.id }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func markAsRead(_ email: Email) {
        guard !email.isRead else { return }

        Task {
            do {
                try await GmailService.shared.markAsRead(id: email.id)
                await MainActor.run {
                    if let index = self.emails.firstIndex(where: { $0.id == email.id }) {
                        self.emails[index].isRead = true
                    }
                }
            } catch {
                // Silently fail for mark as read
            }
        }
    }

    func sendEmail(_ email: Email) {
        Task {
            do {
                try await GmailService.shared.sendEmail(email)
                await MainActor.run {
                    // Could show success message
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func replyToEmail(_ email: Email, body: String) {
        Task {
            do {
                try await GmailService.shared.replyToEmail(originalEmail: email, replyBody: body)
                await MainActor.run {
                    // Could show success message
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    EmailView()
        .frame(width: 400, height: 500)
}
