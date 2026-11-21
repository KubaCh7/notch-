import AppKit

struct ReleaseInfo: Equatable {
    let version: String
    let build: Int
    let notes: String
    let dmgURL: URL
    let pageURL: URL
}

/// Minimal self-updater backed by GitHub Releases.
/// Each CI build is tagged `v1.0.<build>` and carries `NotchPlus.dmg`.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    static let repository = "KubaCh7/notch-"
    static let releasesPage = URL(string: "https://github.com/\(repository)/releases")!

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case downloading
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var available: ReleaseInfo?
    @Published private(set) var lastChecked: Date?

    private var timer: Timer?
    private var promptedBuild = 0

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }

    var isBusy: Bool {
        state == .checking || state == .downloading || state == .installing
    }

    // MARK: Scheduling

    func startAutomaticChecks() {
        timer?.invalidate()
        timer = nil
        guard AppSettings.shared.autoCheckUpdates else { return }

        Task { await check(userInitiated: false) }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.check(userInitiated: false) }
        }
    }

    // MARK: Check

    func check(userInitiated: Bool) async {
        guard !isBusy else { return }
        state = .checking
        do {
            let release = try await fetchLatestRelease()
            lastChecked = Date()
            if release.build > currentBuild {
                available = release
                state = .idle
                let skipped = AppSettings.shared.skippedBuild
                if userInitiated || (release.build != skipped && release.build != promptedBuild) {
                    promptedBuild = release.build
                    promptToInstall(release, allowSkip: !userInitiated)
                }
            } else {
                available = nil
                state = .upToDate
                if userInitiated {
                    showAlert(title: "You're up to date",
                              message: "Notch+ \(currentVersion) is the newest version.")
                }
            }
        } catch {
            state = .failed(error.localizedDescription)
            if userInitiated {
                showAlert(title: "Couldn't check for updates", message: error.localizedDescription)
            }
        }
    }

    private func fetchLatestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NotchPlus-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateError.message("GitHub didn't return a release.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else {
            throw UpdateError.message("Unexpected response from GitHub.")
        }

        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard let build = version.split(separator: ".").last.flatMap({ Int($0) }) else {
            throw UpdateError.message("Release \(tag) has no build number.")
        }
        guard let asset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
              let urlString = asset["browser_download_url"] as? String,
              let dmgURL = URL(string: urlString) else {
            throw UpdateError.message("Release \(tag) has no DMG.")
        }
        let page = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? Self.releasesPage
        return ReleaseInfo(version: version,
                           build: build,
                           notes: (json["body"] as? String) ?? "",
                           dmgURL: dmgURL,
                           pageURL: page)
    }

    // MARK: Install

    func install(_ release: ReleaseInfo) async {
        guard !isBusy else { return }
        let target = Bundle.main.bundleURL
        let parent = target.deletingLastPathComponent()

        guard target.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: parent.path) else {
            showAlert(title: "Can't update here",
                      message: "Move Notch+ to the Applications folder, then try again.")
            return
        }

        state = .downloading
        do {
            let (downloaded, response) = try await URLSession.shared.download(from: release.dmgURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError.message("Download failed.")
            }

            state = .installing
            let staged = try await Task.detached(priority: .userInitiated) {
                try Self.stage(dmg: downloaded)
            }.value

            try Self.launchSwap(staged: staged, target: target)
            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
            showAlert(title: "Update failed", message: error.localizedDescription)
        }
    }

    /// Mounts the DMG, copies the app into a temp folder and returns its URL.
    nonisolated private static func stage(dmg downloaded: URL) throws -> URL {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("NotchPlusUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let dmg = work.appendingPathComponent("NotchPlus.dmg")
        try fm.moveItem(at: downloaded, to: dmg)

        let mount = work.appendingPathComponent("mount")
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen",
                                     "-mountpoint", mount.path])
        defer { try? run("/usr/bin/hdiutil", ["detach", mount.path, "-quiet", "-force"]) }

        let source = mount.appendingPathComponent("NotchPlus.app")
        guard fm.fileExists(atPath: source.path) else {
            throw UpdateError.message("The DMG doesn't contain NotchPlus.app.")
        }
        let staged = work.appendingPathComponent("NotchPlus.app")
        try run("/usr/bin/ditto", [source.path, staged.path])

        guard Bundle(url: staged)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.message("The downloaded app isn't Notch+.")
        }
        return staged
    }

    /// Starts a detached shell that waits for this process to quit, swaps the
    /// bundle and relaunches the new version.
    private static func launchSwap(staged: URL, target: URL) throws {
        let script = """
        while /bin/kill -0 "$NP_PID" 2>/dev/null; do /bin/sleep 0.2; done
        /bin/rm -rf "$NP_TARGET"
        /usr/bin/ditto "$NP_STAGED" "$NP_TARGET"
        /usr/bin/xattr -cr "$NP_TARGET"
        /usr/bin/open "$NP_TARGET"
        /bin/rm -rf "$NP_WORK"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        var environment = ProcessInfo.processInfo.environment
        environment["NP_PID"] = String(ProcessInfo.processInfo.processIdentifier)
        environment["NP_TARGET"] = target.path
        environment["NP_STAGED"] = staged.path
        environment["NP_WORK"] = staged.deletingLastPathComponent().path
        process.environment = environment
        try process.run()
    }

    nonisolated private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.message("\((tool as NSString).lastPathComponent) failed (\(process.terminationStatus)).")
        }
    }

    // MARK: UI

    private func promptToInstall(_ release: ReleaseInfo, allowSkip: Bool) {
        let alert = NSAlert()
        alert.messageText = "Update available"
        var text = "Notch+ \(release.version) is available. You have \(currentVersion)."
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { text += "\n\n\(notes)" }
        alert.informativeText = text
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Later")
        if allowSkip { alert.addButton(withTitle: "Skip This Version") }

        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task { await install(release) }
        case .alertThirdButtonReturn:
            AppSettings.shared.skippedBuild = release.build
        default:
            break
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}

enum UpdateError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
