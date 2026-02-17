import Foundation
import AppKit

class UpdateService: ObservableObject {
    static let shared = UpdateService()

    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?
    @Published var releaseNotes: String?
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var error: String?
    @Published var checkedOnce = false

    private let githubOwner = "ShaharHarel21"
    private let githubRepo = "ezLander"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private init() {}

    // MARK: - Check for Updates
    func checkForUpdates() async {
        await MainActor.run {
            isCheckingForUpdates = true
            error = nil
        }

        do {
            let release = try await fetchLatestRelease()

            await MainActor.run {
                isCheckingForUpdates = false
                checkedOnce = true
                error = nil

                if let tagName = release.tagName {
                    let remoteVersion = tagName.replacingOccurrences(of: "v", with: "")
                    latestVersion = remoteVersion
                    releaseNotes = release.body

                    if isNewerVersion(remoteVersion, than: currentVersion) {
                        updateAvailable = true
                        // Find the .app.zip or .dmg asset
                        if let asset = release.assets?.first(where: {
                            $0.name?.hasSuffix(".zip") == true || $0.name?.hasSuffix(".dmg") == true
                        }) {
                            downloadURL = URL(string: asset.browserDownloadURL ?? "")
                        }
                    } else {
                        updateAvailable = false
                    }
                }
            }
        } catch let updateError as UpdateError {
            await MainActor.run {
                isCheckingForUpdates = false
                checkedOnce = true
                // For "no releases found", treat as up-to-date (repo might be new)
                if case .noReleasesFound = updateError {
                    updateAvailable = false
                    latestVersion = currentVersion
                } else {
                    self.error = updateError.localizedDescription
                }
            }
        } catch {
            await MainActor.run {
                isCheckingForUpdates = false
                checkedOnce = true
                updateAvailable = false
                latestVersion = currentVersion
            }
        }
    }

    // MARK: - Fetch Latest Release from GitHub
    private func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }

        // 404 means no releases yet
        if httpResponse.statusCode == 404 {
            throw UpdateError.noReleasesFound
        }

        guard httpResponse.statusCode == 200 else {
            throw UpdateError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    // MARK: - Download and Install Update
    func downloadAndInstall() async {
        guard let downloadURL = downloadURL else {
            await MainActor.run {
                error = "No download URL available"
            }
            return
        }

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            error = nil
        }

        do {
            // Download the update
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)

            // Move to Downloads folder
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let fileName = downloadURL.lastPathComponent
            let destinationURL = downloadsURL.appendingPathComponent(fileName)

            // Remove existing file if present
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
            }

            // If it's a ZIP, unzip and open
            if fileName.hasSuffix(".zip") {
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProcess.arguments = ["-o", destinationURL.path, "-d", downloadsURL.path]
                try unzipProcess.run()
                unzipProcess.waitUntilExit()

                // Open the app location
                NSWorkspace.shared.selectFile(downloadsURL.appendingPathComponent("EzLander.app").path,
                                             inFileViewerRootedAtPath: downloadsURL.path)

                // Show instructions
                await MainActor.run {
                    showInstallInstructions(appPath: downloadsURL.appendingPathComponent("EzLander.app"))
                }
            } else if fileName.hasSuffix(".dmg") {
                // Open the DMG
                NSWorkspace.shared.open(destinationURL)
            }

        } catch {
            await MainActor.run {
                isDownloading = false
                self.error = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Show Install Instructions
    private func showInstallInstructions(appPath: URL) {
        let alert = NSAlert()
        alert.messageText = "Update Downloaded"
        alert.informativeText = "The new version has been downloaded to your Downloads folder.\n\n1. Quit ezLander\n2. Move the new EzLander.app to Applications (replace existing)\n3. Open the new version"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Quit & Install")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Quit the app so user can install
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Version Comparison
    private func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteComponents = remote.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteComponents.count, currentComponents.count) {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let c = i < currentComponents.count ? currentComponents[i] : 0

            if r > c { return true }
            if r < c { return false }
        }

        return false
    }
}

// MARK: - GitHub API Models
struct GitHubRelease: Codable {
    let tagName: String?
    let name: String?
    let body: String?
    let assets: [GitHubAsset]?
    let htmlUrl: String?
}

struct GitHubAsset: Codable {
    let name: String?
    let browserDownloadURL: String?
    let size: Int?
}

// MARK: - Errors
enum UpdateError: Error, LocalizedError {
    case invalidResponse
    case noReleasesFound
    case apiError(statusCode: Int)
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .noReleasesFound:
            return "No releases found"
        case .apiError(let code):
            return "API error: \(code)"
        case .downloadFailed:
            return "Download failed"
        }
    }
}
