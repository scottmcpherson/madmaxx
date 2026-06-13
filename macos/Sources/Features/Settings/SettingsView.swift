import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    claudeContent
                } header: {
                    agentSectionHeader(title: "Claude Code", imageName: "ClaudeAgentIcon")
                }

                Section {
                    codexContent
                } header: {
                    agentSectionHeader(title: "Codex", imageName: "CodexAgentIcon")
                }

                Section("Maxx") {
                    LabeledContent("Configuration") {
                        Button("Open Config…", action: model.openGhosttyConfig)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("MaxxSettingsGhosttyConfigButton")
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
                .accessibilityIdentifier("MaxxSettingsRefreshButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 420, minHeight: 360)
        .accessibilityIdentifier("MaxxSettingsView")
    }

    // MARK: - Claude Code

    @ViewBuilder
    private var claudeContent: some View {
        integrationRow(
            status: model.claudeIntegrationStatus,
            install: model.installClaudeIntegration,
            uninstall: model.uninstallClaudeIntegration,
            helpText: "Lets Claude Code open new Maxx tabs and run commands in them",
            accessibilityPrefix: "MaxxSettingsClaudeIntegration")

        Picker("Agent tab permission mode", selection: $model.claudeTabPermissionMode) {
            Text("Default").tag("default")
            Text("Plan").tag("plan")
            Text("Accept Edits").tag("acceptEdits")
            Text("Auto").tag("auto")
            Text("Don't Ask").tag("dontAsk")
            Text("Bypass Permissions").tag("bypassPermissions")
        }
        .help("Permission mode for Claude Code sessions that agents start in new tabs. "
            + "Applied unless the spawning agent passes explicit permission flags.")
        .accessibilityIdentifier("MaxxSettingsClaudeTabPermissionModePicker")
    }

    // MARK: - Codex

    @ViewBuilder
    private var codexContent: some View {
        integrationRow(
            status: model.codexIntegrationStatus,
            install: model.installCodexIntegration,
            uninstall: model.uninstallCodexIntegration,
            helpText: "Installs Codex hooks and the Maxx tab-control skill",
            accessibilityPrefix: "MaxxSettingsCodexIntegration")

        Picker("Agent tab sandbox mode", selection: $model.codexTabSandboxMode) {
            Text("Default").tag("default")
            Text("Read Only").tag("read-only")
            Text("Workspace Write").tag("workspace-write")
            Text("Full Auto").tag("full-auto")
            Text("Danger Full Access").tag("danger-full-access")
            Text("Bypass Approvals and Sandbox").tag("bypass")
        }
        .help("Sandbox mode for Codex sessions that agents start in new tabs. "
            + "Applied unless the spawning agent passes explicit sandbox flags.")
        .accessibilityIdentifier("MaxxSettingsCodexTabSandboxModePicker")
    }

    // MARK: - Helpers

    private func agentSectionHeader(title: String, imageName: String) -> some View {
        HStack(spacing: 8) {
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .accessibilityHidden(true)

            Text(title)
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func integrationRow(
        status: AgentIntegrationStatus,
        install: @escaping () -> Void,
        uninstall: @escaping () -> Void,
        helpText: String,
        accessibilityPrefix: String
    ) -> some View {
        LabeledContent("Maxx integration") {
            switch status {
            case .installed:
                Button("Remove", action: uninstall)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("\(accessibilityPrefix)RemoveButton")

            case .installing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Working…")
                        .foregroundStyle(.secondary)
                }

            case .notInstalled:
                Button("Install", action: install)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("\(accessibilityPrefix)InstallButton")

            case .failed:
                Button("Retry", action: install)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("\(accessibilityPrefix)RetryButton")
            }
        }
        .help(helpText)

        if let failureMessage = status.failureMessage {
            Text(failureMessage)
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

final class SettingsViewModel: ObservableObject {
    /// UserDefaults keys for the default permission mode of agent-spawned
    /// tabs. Sync with `src/agent_hook/new_tab.zig`, which reads them when
    /// spawning claude/codex without explicit permission flags.
    static let claudeTabPermissionModeKey = "agentTabClaudePermissionMode"
    static let codexTabSandboxModeKey = "agentTabCodexSandboxMode"

    @Published private(set) var claudeSkillStatus: AgentInstallStatus = .notInstalled
    @Published private(set) var codexStatus: AgentInstallStatus = .notInstalled
    @Published private(set) var codexSkillStatus: AgentInstallStatus = .notInstalled

    @Published var claudeTabPermissionMode: String {
        didSet { Self.persistMode(claudeTabPermissionMode, forKey: Self.claudeTabPermissionModeKey) }
    }

    @Published var codexTabSandboxMode: String {
        didSet { Self.persistMode(codexTabSandboxMode, forKey: Self.codexTabSandboxModeKey) }
    }

    init() {
        self.claudeTabPermissionMode =
            UserDefaults.standard.string(forKey: Self.claudeTabPermissionModeKey) ?? "default"
        self.codexTabSandboxMode =
            UserDefaults.standard.string(forKey: Self.codexTabSandboxModeKey) ?? "default"
    }

    var claudeIntegrationStatus: AgentIntegrationStatus {
        AgentIntegrationStatus(skillStatus: claudeSkillStatus)
    }

    var codexIntegrationStatus: AgentIntegrationStatus {
        if codexStatus == .installing || codexSkillStatus == .installing {
            return .installing
        }

        if let failureMessage = Self.failureMessage(in: [codexStatus, codexSkillStatus]) {
            return .failed(failureMessage)
        }

        return codexStatus == .installed && codexSkillStatus == .installed
            ? .installed
            : .notInstalled
    }

    /// "default" means "no opinion", which we persist as an absent key so the
    /// helper can skip the lookup cleanly.
    private static func persistMode(_ mode: String, forKey key: String) {
        if mode == "default" {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(mode, forKey: key)
        }
    }

    func refresh() {
        if claudeSkillStatus != .installing {
            claudeSkillStatus = CodexHooksManager.claudeSkillInstalled() ? .installed : .notInstalled
        }
        if codexStatus != .installing && codexSkillStatus != .installing {
            refreshCodexIntegrationStatus()
        }
    }

    func openGhosttyConfig() {
        (NSApp.delegate as? AppDelegate)?.openConfig(nil)
    }

    func installClaudeIntegration() {
        runSkillHelper(action: "install", agent: "claude", status: \.claudeSkillStatus,
                       installed: CodexHooksManager.claudeSkillInstalled)
    }

    func uninstallClaudeIntegration() {
        runSkillHelper(action: "uninstall", agent: "claude", status: \.claudeSkillStatus,
                       installed: CodexHooksManager.claudeSkillInstalled)
    }

    func installCodexIntegration() {
        runCodexIntegration(.install)
    }

    func uninstallCodexIntegration() {
        runCodexIntegration(.uninstall)
    }

    private enum CodexIntegrationAction {
        case install
        case uninstall
    }

    private func runCodexIntegration(_ action: CodexIntegrationAction) {
        guard codexStatus != .installing && codexSkillStatus != .installing else { return }

        codexStatus = .installing
        codexSkillStatus = .installing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let failure: String?
            switch action {
            case .install:
                failure = Self.installCodexIntegrationComponents()
            case .uninstall:
                failure = Self.uninstallCodexIntegrationComponents()
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshCodexIntegrationStatus(failureMessage: failure)
            }
        }
    }

    private static func installCodexIntegrationComponents() -> String? {
        if !CodexHooksManager.hooksInstalled() {
            let result = CodexHooksManager.runHook(action: "install")
            guard result.success else { return result.message ?? "Install failed." }
        }

        if !CodexHooksManager.codexSkillInstalled() {
            let result = CodexHooksManager.runHelper(arguments: ["install", "codex-skill"])
            guard result.success else { return result.message ?? "Install failed." }
        }

        return nil
    }

    private static func uninstallCodexIntegrationComponents() -> String? {
        var failure: String?

        let hookResult = CodexHooksManager.runHook(action: "uninstall")
        if !hookResult.success {
            failure = hookResult.message ?? "Uninstall failed."
        }

        let skillResult = CodexHooksManager.runHelper(arguments: ["uninstall", "codex-skill"])
        if !skillResult.success && failure == nil {
            failure = skillResult.message ?? "Uninstall failed."
        }

        return failure
    }

    private func refreshCodexIntegrationStatus(failureMessage: String? = nil) {
        let hooksInstalled = CodexHooksManager.hooksInstalled()
        let skillInstalled = CodexHooksManager.codexSkillInstalled()

        if let failureMessage, !hooksInstalled || !skillInstalled {
            codexStatus = hooksInstalled ? .installed : .failed(failureMessage)
            codexSkillStatus = skillInstalled ? .installed : .failed(failureMessage)
        } else {
            codexStatus = hooksInstalled ? .installed : .notInstalled
            codexSkillStatus = skillInstalled ? .installed : .notInstalled
        }
    }

    private func runSkillHelper(
        action: String,
        agent: String,
        status: ReferenceWritableKeyPath<SettingsViewModel, AgentInstallStatus>,
        installed: @escaping () -> Bool
    ) {
        guard self[keyPath: status] != .installing else { return }

        self[keyPath: status] = .installing
        let failureFallback = action == "install" ? "Install failed." : "Uninstall failed."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = CodexHooksManager.runHelper(arguments: [action, agent])
            DispatchQueue.main.async {
                guard let self else { return }
                if result.success {
                    self[keyPath: status] = installed() ? .installed : .notInstalled
                } else {
                    self[keyPath: status] = installed()
                        ? .installed
                        : .failed(result.message ?? failureFallback)
                }
            }
        }
    }

    private static func failureMessage(in statuses: [AgentInstallStatus]) -> String? {
        for status in statuses {
            if case .failed(let message) = status {
                return message
            }
        }
        return nil
    }
}

enum AgentIntegrationStatus: Equatable {
    case installed
    case notInstalled
    case installing
    case failed(String)

    init(skillStatus: AgentInstallStatus) {
        switch skillStatus {
        case .installed:
            self = .installed
        case .notInstalled:
            self = .notInstalled
        case .installing:
            self = .installing
        case .failed(let message):
            self = .failed(message)
        }
    }

    var failureMessage: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}

enum AgentInstallStatus: Equatable {
    case installed
    case notInstalled
    case installing
    case failed(String)
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(model: SettingsViewModel())
            .frame(width: 460, height: 480)
    }
}
