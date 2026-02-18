import SwiftUI
import WebKit
import CryptoKit

struct EmailView: View {
    @StateObject private var viewModel = EmailViewModel.shared
    @State private var selectedEmail: Email?
    @State private var openedEmail: Email?
    @State private var showingCompose = false
    @State private var replyToEmail: Email?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var successMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = viewModel.error, showingError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button(action: {
                        showingError = false
                        viewModel.error = nil
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
            }

            // Success banner
            if showingSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.caption)
                    Spacer()
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showingSuccess = false
                    }
                }
            }

            // Undo delete banner
            if viewModel.showUndoBanner {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Email deleted")
                        .font(.caption)
                    Spacer()
                    Button("Undo") {
                        withAnimation {
                            viewModel.undoDelete()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.warmPrimary)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Header
            emailHeader

            Divider()

            // Content
            if !viewModel.isConnected {
                notConnectedView
            } else if viewModel.isLoading && viewModel.emails.isEmpty {
                loadingView
            } else if let opened = openedEmail {
                emailDetailView(email: opened)
            } else {
                emailListView
            }
        }
        .onChange(of: viewModel.error) { newError in
            if newError != nil {
                showingError = true
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
        .sheet(item: $replyToEmail) { email in
            ReplyEmailView(
                originalEmail: email,
                onSend: { replyBody in
                    viewModel.replyToEmail(email, body: replyBody) { success in
                        if success {
                            successMessage = "Reply sent successfully"
                            showingSuccess = true
                        }
                    }
                    replyToEmail = nil
                },
                onCancel: {
                    replyToEmail = nil
                }
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Header
    private var emailHeader: some View {
        HStack {
            if openedEmail != nil {
                Button(action: { openedEmail = nil }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
            }

            if openedEmail != nil {
                Text("Email")
                    .font(.headline)
            } else {
                folderMenu
            }

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

    // MARK: - Folder Menu
    private var folderMenu: some View {
        Menu {
            // Inbox (nil = default)
            Button(action: { viewModel.selectFolder(nil) }) {
                Label {
                    Text("Inbox")
                } icon: {
                    Image(systemName: viewModel.selectedFolder == nil ? "checkmark" : "tray")
                }
            }

            // System labels in a fixed order
            let systemOrder = ["STARRED", "SENT", "DRAFT", "SPAM", "TRASH"]
            let systemLabels = systemOrder.compactMap { id in
                viewModel.browsableLabels.first { $0.id == id }
            }

            ForEach(systemLabels) { label in
                Button(action: { viewModel.selectFolder(label) }) {
                    Label {
                        Text(label.displayName)
                    } icon: {
                        Image(systemName: viewModel.selectedFolder?.id == label.id ? "checkmark" : label.icon)
                    }
                }
            }

            // User/custom labels
            let userLabels = viewModel.browsableLabels
                .filter { $0.type == "user" }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            if !userLabels.isEmpty {
                Divider()
                ForEach(userLabels) { label in
                    Button(action: { viewModel.selectFolder(label) }) {
                        Label {
                            Text(label.displayName)
                        } icon: {
                            Image(systemName: viewModel.selectedFolder?.id == label.id ? "checkmark" : "tag")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.selectedFolderIcon)
                    .font(.subheadline)
                Text(viewModel.selectedFolderName)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
                        isSelected: selectedEmail?.id == email.id,
                        onTap: {
                            selectedEmail = email
                        },
                        onDoubleTap: {
                            selectedEmail = email
                            openedEmail = email
                            viewModel.markAsRead(email)
                        },
                        onReply: {
                            replyToEmail = email
                        },
                        onArchive: {
                            viewModel.archiveEmail(email)
                        },
                        onDelete: {
                            viewModel.deleteEmail(email)
                        },
                        onMarkRead: {
                            if email.isRead {
                                viewModel.markAsUnread(email)
                            } else {
                                viewModel.markAsRead(email)
                            }
                        },
                        onMove: { label in
                            viewModel.moveEmail(email, to: label)
                        },
                        availableLabels: viewModel.availableLabels
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
                    SenderAvatarView(
                        email: email.senderEmail,
                        name: email.senderName,
                        size: 36
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
                }) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    viewModel.archiveEmail(email)
                    openedEmail = nil
                }) {
                    Label("Archive", systemImage: "archivebox")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: {
                    viewModel.deleteEmail(email)
                    openedEmail = nil
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                if !viewModel.availableLabels.isEmpty {
                    Menu {
                        ForEach(viewModel.availableLabels) { label in
                            Button(action: {
                                viewModel.moveEmail(email, to: label)
                                openedEmail = nil
                            }) {
                                Label(label.displayName, systemImage: label.icon)
                            }
                        }
                    } label: {
                        Label("Move to", systemImage: "folder")
                    }
                    .menuStyle(.borderlessButton)
                }

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
    var isSelected: Bool = false
    let onTap: () -> Void
    var onDoubleTap: (() -> Void)?
    let onReply: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onMarkRead: () -> Void
    var onMove: ((GmailLabel) -> Void)?
    var availableLabels: [GmailLabel] = []

    @State private var isHovered = false
    @State private var swipeOffset: CGFloat = 0
    @State private var lastClickTime: Date = .distantPast

    private let swipeThreshold: CGFloat = 80

    var body: some View {
        ZStack {
            // Background actions revealed by swipe
            HStack(spacing: 0) {
                // Right swipe background (Archive)
                HStack {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    if swipeOffset > swipeThreshold {
                        Text("Archive")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: max(swipeOffset, 0))
                .frame(maxHeight: .infinity)
                .background(Color.warmAccent)
                .clipped()

                Spacer()

                // Left swipe background (Delete)
                HStack {
                    if swipeOffset < -swipeThreshold {
                        Text("Delete")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .frame(width: max(-swipeOffset, 0))
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .clipped()
            }

            // Main row content
            HStack(spacing: 12) {
                // Sender avatar
                SenderAvatarView(
                    email: email.senderEmail,
                    name: email.senderName,
                    size: 40,
                    isRead: email.isRead
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
                if isHovered && swipeOffset == 0 {
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
            .background(
                isSelected
                    ? Color.warmPrimary.opacity(0.12)
                    : (isHovered && swipeOffset == 0 ? Color(NSColor.controlBackgroundColor) : Color(NSColor.windowBackgroundColor))
            )
            .offset(x: swipeOffset)
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        // Only allow horizontal swipe
                        if abs(value.translation.width) > abs(value.translation.height) {
                            withAnimation(.interactiveSpring()) {
                                swipeOffset = value.translation.width
                            }
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        if swipeOffset > swipeThreshold || velocity > 200 {
                            // Swipe right — Archive
                            withAnimation(.easeOut(duration: 0.2)) {
                                swipeOffset = 400
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onArchive()
                            }
                        } else if swipeOffset < -swipeThreshold || velocity < -200 {
                            // Swipe left — Delete
                            withAnimation(.easeOut(duration: 0.2)) {
                                swipeOffset = -400
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDelete()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                swipeOffset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if swipeOffset != 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    swipeOffset = 0
                }
                return
            }
            let now = Date()
            if now.timeIntervalSince(lastClickTime) < 0.3 {
                onDoubleTap?()
                lastClickTime = .distantPast
            } else {
                onTap()
                lastClickTime = now
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            Divider()

            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }

            Button(action: onMarkRead) {
                Label(email.isRead ? "Mark as Unread" : "Mark as Read",
                      systemImage: email.isRead ? "envelope.badge" : "envelope.open")
            }

            if !availableLabels.isEmpty, let onMove = onMove {
                Menu {
                    ForEach(availableLabels) { label in
                        Button(action: { onMove(label) }) {
                            Label(label.displayName, systemImage: label.icon)
                        }
                    }
                } label: {
                    Label("Move to...", systemImage: "folder")
                }
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
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

// MARK: - Sender Avatar View
struct SenderAvatarView: View {
    let email: String
    let name: String
    let size: CGFloat
    var isRead: Bool = false

    @StateObject private var loader = AvatarImageLoader()

    // Gmail-style palette for initials circles
    private static let avatarColors: [Color] = [
        Color(red: 0.92, green: 0.34, blue: 0.34), // Red
        Color(red: 0.90, green: 0.49, blue: 0.13), // Orange
        Color(red: 0.78, green: 0.68, blue: 0.16), // Yellow
        Color(red: 0.26, green: 0.63, blue: 0.28), // Green
        Color(red: 0.00, green: 0.59, blue: 0.53), // Teal
        Color(red: 0.13, green: 0.59, blue: 0.95), // Blue
        Color(red: 0.25, green: 0.32, blue: 0.71), // Indigo
        Color(red: 0.40, green: 0.23, blue: 0.72), // Deep Purple
        Color(red: 0.61, green: 0.15, blue: 0.69), // Purple
        Color(red: 0.76, green: 0.18, blue: 0.42), // Pink
    ]

    private var senderColor: Color {
        let hash = email.lowercased().utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        let index = abs(hash) % Self.avatarColors.count
        return Self.avatarColors[index]
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback: colored circle with initial (consistent per-sender color)
                Circle()
                    .fill(isRead ? senderColor.opacity(0.15) : senderColor.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(isRead ? senderColor.opacity(0.6) : senderColor)
                    )
            }
        }
        .onAppear {
            loader.load(email: email)
        }
        .onChange(of: email) { newEmail in
            loader.load(email: newEmail)
        }
    }
}

// MARK: - Avatar Image Loader
class AvatarImageLoader: ObservableObject {
    @Published var image: NSImage?

    private static var cache = NSCache<NSString, NSImage>()
    private var currentEmail: String?

    private static let freeProviders: Set<String> = [
        "gmail.com", "yahoo.com", "hotmail.com", "outlook.com",
        "aol.com", "icloud.com", "me.com", "mail.com",
        "protonmail.com", "proton.me", "live.com", "msn.com",
        "ymail.com", "googlemail.com"
    ]

    func load(email: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else { return }
        guard cleanEmail != currentEmail else { return }
        currentEmail = cleanEmail

        // Check cache
        if let cached = Self.cache.object(forKey: cleanEmail as NSString) {
            self.image = cached
            return
        }

        let domain = cleanEmail.components(separatedBy: "@").last ?? ""

        Task {
            // 1. Try Google People API (profile photo)
            if let img = await fetchGoogleProfilePhoto(email: cleanEmail) {
                await setImage(img, forKey: cleanEmail)
                return
            }

            // 2. Try Gravatar
            if let img = await fetchGravatar(email: cleanEmail) {
                await setImage(img, forKey: cleanEmail)
                return
            }

            // 3. Try company logos (skip free email providers)
            if !domain.isEmpty, !Self.freeProviders.contains(domain) {
                // 3a. Try Clearbit logo
                if let img = await fetchClearbitLogo(domain: domain) {
                    await setImage(img, forKey: cleanEmail)
                    return
                }

                // 3b. Try Google Favicon
                if let img = await fetchGoogleFavicon(domain: domain) {
                    await setImage(img, forKey: cleanEmail)
                    return
                }
            }

            // 4. No image found — initials fallback handled by SenderAvatarView
        }
    }

    // MARK: - Google People API

    private func fetchGoogleProfilePhoto(email: String) async -> NSImage? {
        do {
            let accessToken = try await OAuthService.shared.getValidAccessToken()

            guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://people.googleapis.com/v1/otherContacts:search?query=\(encodedEmail)&readMask=photos&pageSize=1") else {
                return nil
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse the JSON response to extract photo URL
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstResult = results.first,
                  let person = firstResult["person"] as? [String: Any],
                  let photos = person["photos"] as? [[String: Any]],
                  let photoUrl = photos.first?["url"] as? String,
                  let url = URL(string: photoUrl) else {
                return nil
            }

            return await downloadImage(from: url)
        } catch {
            return nil
        }
    }

    // MARK: - Gravatar

    private func fetchGravatar(email: String) async -> NSImage? {
        let hash = Insecure.MD5
            .hash(data: Data(email.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        guard let url = URL(string: "https://www.gravatar.com/avatar/\(hash)?s=160&d=404") else {
            return nil
        }

        return await downloadImage(from: url)
    }

    // MARK: - Company Logos

    private func fetchClearbitLogo(domain: String) async -> NSImage? {
        guard let url = URL(string: "https://logo.clearbit.com/\(domain)?size=160") else {
            return nil
        }
        return await downloadImage(from: url)
    }

    private func fetchGoogleFavicon(domain: String) async -> NSImage? {
        guard let url = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128") else {
            return nil
        }

        // Google favicons always return something — filter out the tiny default globe icon
        guard let img = await downloadImage(from: url) else { return nil }
        let rep = img.representations.first
        let width = rep?.pixelsWide ?? Int(img.size.width)
        // If the returned icon is 16x16 or smaller, it's likely the default — skip it
        if width <= 16 { return nil }
        return img
    }

    // MARK: - Helpers

    private func downloadImage(from url: URL) async -> NSImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data),
                  image.isValid else {
                return nil
            }
            return image
        } catch {
            return nil
        }
    }

    @MainActor
    private func setImage(_ img: NSImage, forKey key: String) {
        Self.cache.setObject(img, forKey: key as NSString)
        if currentEmail == key {
            self.image = img
        }
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
                        color: #FFA94D;
                    }
                }
                img {
                    max-width: 100% !important;
                    height: auto !important;
                }
                a {
                    color: #FF6B6B;
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
                /* Strip borders from email layout tables */
                table {
                    border: none !important;
                    border-collapse: collapse;
                    max-width: 100% !important;
                    width: auto !important;
                }
                td, th {
                    border: none !important;
                    padding: 0;
                }
                /* Strip borders and outlines from all common layout elements */
                div, span, p, table, tr, td, th, tbody, thead, tfoot {
                    border-color: transparent !important;
                    outline: none !important;
                }
                /* Remove fixed widths that cause horizontal overflow */
                table, td, th, div {
                    max-width: 100% !important;
                }
                /* Tame inline styles that set explicit borders */
                [style*="border"] {
                    border-color: transparent !important;
                }
                [style*="border-top"], [style*="border-bottom"],
                [style*="border-left"], [style*="border-right"] {
                    border-color: transparent !important;
                }
                /* Keep hr lines subtle */
                hr {
                    border: none;
                    border-top: 1px solid #e0e0e0;
                    margin: 12px 0;
                }
                @media (prefers-color-scheme: dark) {
                    hr {
                        border-top-color: #444;
                    }
                    [style*="border"] {
                        border-color: transparent !important;
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
    @Published var availableLabels: [GmailLabel] = []
    @Published var browsableLabels: [GmailLabel] = []
    @Published var selectedFolder: GmailLabel?
    @Published var showUndoBanner = false

    private var hasLoadedOnce = false
    private var pendingDeleteEmail: Email?
    private var pendingDeleteIndex: Int?
    private var deleteWorkItem: DispatchWorkItem?

    init() {
        checkConnection()
    }

    func onAppear() {
        checkConnection()
        if isConnected && !hasLoadedOnce {
            loadEmails()
            loadLabels()
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
                    loadLabels()
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

        let labelId = selectedFolder?.id ?? "INBOX"

        Task {
            do {
                let fetchedEmails = try await GmailService.shared.listEmailsByLabel(labelId: labelId, maxResults: 20)
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

    func selectFolder(_ label: GmailLabel?) {
        selectedFolder = label
        emails = []
        loadEmails()
    }

    var selectedFolderName: String {
        selectedFolder?.displayName ?? "Inbox"
    }

    var selectedFolderIcon: String {
        selectedFolder?.icon ?? "tray"
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
        // If there's already a pending delete, commit it immediately
        commitPendingDelete()

        // Store the email and its position for undo
        if let index = emails.firstIndex(where: { $0.id == email.id }) {
            pendingDeleteEmail = email
            pendingDeleteIndex = index
        }

        // Optimistically remove from the list
        emails.removeAll { $0.id == email.id }
        showUndoBanner = true

        // Schedule the actual API call after 5 seconds
        let workItem = DispatchWorkItem { [weak self] in
            self?.commitPendingDelete()
        }
        deleteWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    func undoDelete() {
        deleteWorkItem?.cancel()
        deleteWorkItem = nil
        showUndoBanner = false

        if let email = pendingDeleteEmail, let index = pendingDeleteIndex {
            let insertAt = min(index, emails.count)
            emails.insert(email, at: insertAt)
        }
        pendingDeleteEmail = nil
        pendingDeleteIndex = nil
    }

    private func commitPendingDelete() {
        deleteWorkItem?.cancel()
        deleteWorkItem = nil
        showUndoBanner = false

        guard let email = pendingDeleteEmail else { return }
        pendingDeleteEmail = nil
        pendingDeleteIndex = nil

        Task {
            do {
                try await GmailService.shared.deleteEmail(id: email.id)
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

    func markAsUnread(_ email: Email) {
        guard email.isRead else { return }

        Task {
            do {
                try await GmailService.shared.markAsUnread(id: email.id)
                await MainActor.run {
                    if let index = self.emails.firstIndex(where: { $0.id == email.id }) {
                        self.emails[index].isRead = false
                    }
                }
            } catch {
                // Silently fail for mark as unread
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

    func loadLabels() {
        Task {
            do {
                let labels = try await GmailService.shared.listLabels()
                await MainActor.run {
                    self.availableLabels = labels.filter { $0.isMoveTarget }
                        .sorted { $0.displayName < $1.displayName }
                    self.browsableLabels = labels.filter { $0.isBrowsable }
                }
            } catch {
                // Silently fail — labels are a nice-to-have
            }
        }
    }

    func moveEmail(_ email: Email, to label: GmailLabel) {
        Task {
            do {
                try await GmailService.shared.moveEmail(
                    id: email.id,
                    addLabelIds: [label.id],
                    removeLabelIds: ["INBOX"]
                )
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

    func replyToEmail(_ email: Email, body: String, completion: ((Bool) -> Void)? = nil) {
        Task {
            do {
                NSLog("EmailViewModel: Sending reply to email \(email.id)")
                NSLog("EmailViewModel: Original from: \(email.from ?? "nil"), threadId: \(email.threadId ?? "nil")")
                try await GmailService.shared.replyToEmail(originalEmail: email, replyBody: body)
                await MainActor.run {
                    NSLog("EmailViewModel: Reply sent successfully")
                    completion?(true)
                }
            } catch {
                await MainActor.run {
                    NSLog("EmailViewModel: Reply failed - \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    completion?(false)
                }
            }
        }
    }
}

#Preview {
    EmailView()
        .frame(width: 400, height: 500)
}
