import AppKit
import Foundation

/// Single source of truth for detecting, revealing, and installing the Ghostty Codex
/// agent hooks. Both the Settings window and the one-time install prompt go through
/// here so detection and installation never drift apart.
///
/// The hooks are written by the bundled `ghostty-agent-hook` helper, which adds a
/// marked block to `~/.codex/config.toml` and `~/.codex/hooks.json` (or `$CODEX_HOME`).
enum CodexHooksManager {
    /// The Codex home directory, respecting `$CODEX_HOME`, else `~/.codex`.
    static func codexHomeURL() -> URL {
        if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !codexHome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(
                fileURLWithPath: (codexHome as NSString).expandingTildeInPath,
                isDirectory: true)
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".codex", isDirectory: true)
    }

    /// Whether the Codex home directory exists on disk. This is the gate for the
    /// one-time install prompt: the live "Codex is running" signal only exists after
    /// hooks are installed, so we can't use it to decide whether to offer them.
    static func codexHomeExists() -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: codexHomeURL().path,
            isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    /// Whether our hooks are already installed in the Codex config.
    static func hooksInstalled() -> Bool {
        let codexHome = codexHomeURL()
        let hooksURL = codexHome.appendingPathComponent("hooks.json")
        let configURL = codexHome.appendingPathComponent("config.toml")

        guard let hooks = try? String(contentsOf: hooksURL, encoding: .utf8),
              let config = try? String(contentsOf: configURL, encoding: .utf8)
        else {
            return false
        }

        return hooks.contains("ghostty-agent-hook") &&
            hooks.contains(" codex ") &&
            config.contains("ghostty-agent-codex-hooks-feature begin") &&
            config.contains("hooks = true")
    }

    /// Reveal the hook files in Finder, falling back to the Codex home directory.
    static func revealHooks() {
        let codexHome = codexHomeURL()
        let candidates = [
            codexHome.appendingPathComponent("config.toml"),
            codexHome.appendingPathComponent("hooks.json"),
        ]
        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
        NSWorkspace.shared.activateFileViewerSelecting(existing.isEmpty ? [codexHome] : existing)
    }

    /// Run the hook helper for `install` / `uninstall`. This blocks while the helper
    /// runs, so call it off the main thread.
    static func runHook(action: String) -> (success: Bool, message: String?) {
        guard let helperURL else {
            return (false, "Hook helper missing.")
        }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = [action, "codex"]

        var environment = ProcessInfo.processInfo.environment
        if environment["HOME"]?.isEmpty ?? true {
            environment["HOME"] = NSHomeDirectory()
        }
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (false, error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            return (false, output.isEmpty ? nil : output)
        }

        return (true, nil)
    }

    /// Whether the Claude Code CLI helper is available alongside the hook helper.
    static func claudeConfigured() -> Bool {
        guard let helperURL else { return false }
        let claudeURL = helperURL.deletingLastPathComponent().appendingPathComponent("claude")
        return FileManager.default.isExecutableFile(atPath: claudeURL.path)
    }

    /// The bundled `ghostty-agent-hook` helper, if present and executable.
    static var helperURL: URL? {
        guard let resourcesURL = Bundle.main.resourceURL else { return nil }
        let helperURL = resourcesURL
            .appendingPathComponent("ghostty", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("ghostty-agent-hook", isDirectory: false)

        return FileManager.default.isExecutableFile(atPath: helperURL.path) ? helperURL : nil
    }
}
