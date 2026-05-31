import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Claude Code") {
                    claudeContent
                }

                Section("Codex") {
                    codexContent
                }

                Section("Ghostty") {
                    LabeledContent("Configuration") {
                        Button("Open Config…", action: model.openGhosttyConfig)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("MosttlySettingsGhosttyConfigButton")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(action: model.refresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Re-check installed agents")
                .accessibilityIdentifier("MosttlySettingsRefreshButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 420, minHeight: 360)
        .accessibilityIdentifier("MosttlySettingsView")
    }

    // MARK: - Claude Code

    @ViewBuilder
    private var claudeContent: some View {
        if model.claudeConfigured {
            statusRow(title: "Configured", systemImage: "checkmark.circle.fill", tint: .green)
        } else {
            statusRow(title: "Not detected", systemImage: "circle", tint: .secondary)
            LabeledContent("Claude Code CLI") {
                Button("How to Enable…", action: model.openClaudeDocs)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("MosttlySettingsClaudeHelpButton")
            }
        }
    }

    // MARK: - Codex

    @ViewBuilder
    private var codexContent: some View {
        statusRow(
            title: model.codexStatus.title,
            systemImage: model.codexStatus.systemImage,
            tint: model.codexStatus.tint)

        switch model.codexStatus {
        case .installed:
            LabeledContent("Hook files") {
                Button("Reveal in Finder", action: model.revealCodexHooks)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("MosttlySettingsRevealCodexHooksButton")
            }
            LabeledContent("Ghostty integration") {
                Button("Uninstall Hooks", action: model.uninstallCodexHooks)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("MosttlySettingsUninstallCodexHooksButton")
            }

        case .installing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Working…")
                    .foregroundStyle(.secondary)
            }

        case .notInstalled, .failed:
            LabeledContent("Ghostty integration") {
                Button("Install Hooks", action: model.installCodexHooks)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("MosttlySettingsInstallCodexHooksButton")
            }

            if case .failed(let message) = model.codexStatus {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private func statusRow(title: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

final class SettingsViewModel: ObservableObject {
    @Published private(set) var claudeConfigured = false
    @Published private(set) var codexStatus: CodexHooksStatus = .notInstalled

    func refresh() {
        claudeConfigured = CodexHooksManager.claudeConfigured()
        if codexStatus != .installing {
            codexStatus = CodexHooksManager.hooksInstalled() ? .installed : .notInstalled
        }
    }

    func openGhosttyConfig() {
        (NSApp.delegate as? AppDelegate)?.openConfig(nil)
    }

    func openClaudeDocs() {
        guard let url = URL(string: "https://www.anthropic.com/claude-code") else { return }
        NSWorkspace.shared.open(url)
    }

    func installCodexHooks() {
        runCodexHook(action: "install", failureFallback: "Install failed.")
    }

    func uninstallCodexHooks() {
        runCodexHook(action: "uninstall", failureFallback: "Uninstall failed.")
    }

    func revealCodexHooks() {
        CodexHooksManager.revealHooks()
    }

    private func runCodexHook(action: String, failureFallback: String) {
        guard codexStatus != .installing else { return }

        codexStatus = .installing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = CodexHooksManager.runHook(action: action)
            DispatchQueue.main.async {
                guard let self else { return }
                if result.success {
                    self.codexStatus = CodexHooksManager.hooksInstalled() ? .installed : .notInstalled
                } else {
                    self.codexStatus = .failed(result.message ?? failureFallback)
                }
            }
        }
    }
}

enum CodexHooksStatus: Equatable {
    case installed
    case notInstalled
    case installing
    case failed(String)

    var title: String {
        switch self {
        case .installed:
            return "Hooks installed"
        case .notInstalled:
            return "Not installed"
        case .installing:
            return "Working…"
        case .failed:
            return "Last action failed"
        }
    }

    var systemImage: String {
        switch self {
        case .installed:
            return "checkmark.circle.fill"
        case .notInstalled:
            return "circle"
        case .installing:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .installed:
            return .green
        case .notInstalled, .installing:
            return .secondary
        case .failed:
            return .red
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(model: SettingsViewModel())
            .frame(width: 460, height: 480)
    }
}
