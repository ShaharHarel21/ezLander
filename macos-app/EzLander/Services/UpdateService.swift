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
    @Published var isInstalling = false
    @Published var error: String?
    @Published var checkedOnce = false

    private let githubOwner = "ShaharHarel21"
    private let githubRepo = "ezLander"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private init() {
        cleanupPreviousUpdate()
    }

    /// Remove leftover backup and temp files from a previous update
    private func cleanupPreviousUpdate() {
        let parentDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let backupURL = parentDir.appendingPathComponent(".EzLander-old.app")
        try? FileManager.default.removeItem(at: backupURL)

        let updateDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EzLander-update")
        try? FileManager.default.removeItem(at: updateDir)
    }

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
                            downloadURL = URL(string: asset.browserDownloadUrl ?? "")
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
            // Create a clean temp directory for this update
            let updateDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("EzLander-update")
            try? FileManager.default.removeItem(at: updateDir)
            try FileManager.default.createDirectory(at: updateDir, withIntermediateDirectories: true)

            // Download the update file
            let (tempFileURL, _) = try await URLSession.shared.download(from: downloadURL)
            let fileName = downloadURL.lastPathComponent
            let downloadedFile = updateDir.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: downloadedFile)
            try FileManager.default.moveItem(at: tempFileURL, to: downloadedFile)

            await MainActor.run {
                downloadProgress = 1.0
                isDownloading = false
                isInstalling = true
            }

            if fileName.hasSuffix(".zip") {
                // Unzip
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProcess.arguments = ["-o", downloadedFile.path, "-d", updateDir.path]
                try unzipProcess.run()
                unzipProcess.waitUntilExit()

                // Find the .app bundle in extracted contents
                let contents = try FileManager.default.contentsOfDirectory(
                    at: updateDir, includingPropertiesForKeys: nil)
                guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
                    throw UpdateError.downloadFailed
                }

                // Replace current app and relaunch
                try replaceAndRelaunch(with: newAppURL, updateDir: updateDir)

            } else if fileName.hasSuffix(".dmg") {
                // DMG: mount and let the user handle it
                NSWorkspace.shared.open(downloadedFile)
                await MainActor.run {
                    isInstalling = false
                }
            } else {
                await MainActor.run {
                    isInstalling = false
                    self.error = "Unsupported update format"
                }
            }

        } catch {
            await MainActor.run {
                isDownloading = false
                isInstalling = false
                self.error = "Update failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Replace App Bundle and Relaunch
    private func replaceAndRelaunch(with newAppURL: URL, updateDir: URL) throws {
        let currentAppURL = Bundle.main.bundleURL
        let parentDir = currentAppURL.deletingLastPathComponent()
        let backupURL = parentDir.appendingPathComponent(".EzLander-old.app")
        let currentPID = ProcessInfo.processInfo.processIdentifier

        // Clean any leftover backup
        try? FileManager.default.removeItem(at: backupURL)

        // Rename current app to backup (atomic rename, same directory)
        try FileManager.default.moveItem(at: currentAppURL, to: backupURL)

        do {
            // Copy new app to the original location
            try FileManager.default.copyItem(at: newAppURL, to: currentAppURL)
        } catch {
            // Rollback: restore from backup
            try? FileManager.default.moveItem(at: backupURL, to: currentAppURL)
            throw error
        }

        // Spawn a relaunch script that waits for this process to exit,
        // then opens the new app and cleans up
        let script = """
        while kill -0 \(currentPID) 2>/dev/null; do sleep 0.2; done
        open "\(currentAppURL.path)"
        rm -rf "\(backupURL.path)"
        rm -rf "\(updateDir.path)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()

        // Quit the app — the script will relaunch the new version
        DispatchQueue.main.async {
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
    let browserDownloadUrl: String?
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
