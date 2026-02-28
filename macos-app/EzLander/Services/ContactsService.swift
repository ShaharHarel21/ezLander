import Foundation
import Contacts

class ContactsService {
    static let shared = ContactsService()

    private var cachedContacts: [ContactSuggestion] = []
    private var isLoaded = false
    private var isLoading = false

    private init() {}

    // MARK: - Public API

    /// Filter cached contacts matching the query (name or email substring match).
    /// Requires at least 2 characters.
    func suggestions(for query: String, limit: Int = 5) -> [ContactSuggestion] {
        guard query.count >= 2 else { return [] }
        let q = query.lowercased()
        return Array(
            cachedContacts
                .filter { $0.searchableText.contains(q) }
                .prefix(limit)
        )
    }

    /// Load contacts from all sources. Safe to call multiple times — only loads once.
    func loadContactsIfNeeded() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true

        async let google = fetchGoogleContacts()
        async let recent = fetchRecentEmailContacts()
        async let apple = fetchAppleContacts()

        let all = await google + recent + apple

        // Deduplicate: keep highest-priority source per email, prefer entries with names
        var seen: [String: ContactSuggestion] = [:]
        for contact in all.sorted(by: { $0.source < $1.source }) {
            let key = contact.email.lowercased()
            if seen[key] == nil {
                seen[key] = contact
            } else if let existing = seen[key], existing.name.isEmpty && !contact.name.isEmpty {
                seen[key] = contact
            }
        }

        cachedContacts = Array(seen.values).sorted {
            if $0.name.isEmpty != $1.name.isEmpty { return !$0.name.isEmpty }
            let a = $0.name.isEmpty ? $0.email : $0.name
            let b = $1.name.isEmpty ? $1.email : $1.name
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }

        isLoaded = true
        isLoading = false
    }

    /// Force refresh on next load.
    func invalidateCache() {
        isLoaded = false
        cachedContacts = []
    }

    // MARK: - Google People API (otherContacts)

    private func fetchGoogleContacts() async -> [ContactSuggestion] {
        do {
            let accessToken = try await OAuthService.shared.getValidAccessToken()

            guard let url = URL(string: "https://people.googleapis.com/v1/otherContacts?readMask=names,emailAddresses&pageSize=1000") else {
                return []
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contacts = json["otherContacts"] as? [[String: Any]] else {
                return []
            }

            return contacts.compactMap { contact -> ContactSuggestion? in
                guard let emails = contact["emailAddresses"] as? [[String: Any]],
                      let email = emails.first?["value"] as? String else {
                    return nil
                }

                let name: String
                if let names = contact["names"] as? [[String: Any]],
                   let displayName = names.first?["displayName"] as? String {
                    name = displayName
                } else {
                    name = ""
                }

                return ContactSuggestion(
                    id: email.lowercased(),
                    name: name,
                    email: email,
                    source: .googleContacts
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Recent Email Contacts

    private func fetchRecentEmailContacts() async -> [ContactSuggestion] {
        let emails = await MainActor.run { EmailViewModel.shared.emails }

        var contacts: [ContactSuggestion] = []

        for email in emails {
            // From field
            if let from = email.from, !from.isEmpty {
                let addr = EmailParser.extractEmailAddress(from: from)
                let name = email.senderName == "Unknown" ? "" : email.senderName
                if !addr.isEmpty {
                    contacts.append(ContactSuggestion(
                        id: addr.lowercased(), name: name, email: addr, source: .recentEmail
                    ))
                }
            }

            // To field (sent emails)
            if !email.to.isEmpty {
                let addr = EmailParser.extractEmailAddress(from: email.to)
                var name = ""
                if let nameEnd = email.to.firstIndex(of: "<") {
                    name = String(email.to[..<nameEnd]).trimmingCharacters(in: .whitespaces)
                }
                if !addr.isEmpty {
                    contacts.append(ContactSuggestion(
                        id: addr.lowercased(), name: name, email: addr, source: .recentEmail
                    ))
                }
            }
        }

        return contacts
    }

    // MARK: - Apple Contacts

    private func fetchAppleContacts() async -> [ContactSuggestion] {
        let store = CNContactStore()

        var status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            do {
                let granted = try await store.requestAccess(for: .contacts)
                if granted { status = .authorized }
            } catch {
                return []
            }
        }
        guard status == .authorized else { return [] }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        do {
            var results: [ContactSuggestion] = []
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)

            try store.enumerateContacts(with: request) { contact, _ in
                let name = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                for emailEntry in contact.emailAddresses {
                    let email = emailEntry.value as String
                    results.append(ContactSuggestion(
                        id: email.lowercased(),
                        name: name,
                        email: email,
                        source: .appleContacts
                    ))
                }
            }

            return results
        } catch {
            return []
        }
    }
}
