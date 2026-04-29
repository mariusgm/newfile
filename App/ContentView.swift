import SwiftUI
import FinderSync

@MainActor
final class SetupStatus: ObservableObject {
    @Published private(set) var extensionEnabled: Bool = false
    @Published private(set) var hasUsedAction: Bool = false

    private let usedKey = "hasUsedAction"
    private let firstUseNotification =
        Notification.Name("dev.newfile.NewFile.toolbarOrMenuUsed")

    init() {
        hasUsedAction = UserDefaults.standard.bool(forKey: usedKey)
        refresh()
        DistributedNotificationCenter.default().addObserver(
            forName: firstUseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.markUsed()
        }
    }

    func refresh() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
    }

    private func markUsed() {
        if !hasUsedAction {
            hasUsedAction = true
            UserDefaults.standard.set(true, forKey: usedKey)
        }
    }
}

struct ContentView: View {
    @StateObject private var status = SetupStatus()

    private let horizontalPadding: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 28) {
                    StepView(
                        badge: .number(1, isComplete: status.extensionEnabled),
                        title: "Enable the Finder extension",
                        description: .path("System Settings → General → Login Items & Extensions → Added Extensions → toggle NewFile Extension."),
                        primaryButton: PrimaryButton(
                            title: status.extensionEnabled
                                ? "Manage in System Settings"
                                : "Open Login Items & Extensions",
                            action: openExtensionsSettings,
                            prominent: !status.extensionEnabled
                        )
                    )
                    StepView(
                        badge: .number(2, isComplete: status.hasUsedAction),
                        title: "Use it",
                        description: .twoLine(
                            primary: "Right-click anywhere in a Finder window → New Text File.",
                            secondary: "Creates New Text File.txt, auto-numbered if one already exists."
                        ),
                        primaryButton: nil
                    )
                }
                StepView(
                    badge: .optional,
                    title: "Add a toolbar button",
                    titlePrefix: "OPTIONAL",
                    description: .path("View → Customize Toolbar… → drag the NewFile icon into the toolbar."),
                    primaryButton: nil
                )
                .padding(.top, 40)
            }

            Spacer(minLength: 24)

            footer
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 40)
        .padding(.bottom, 24)
        .frame(minWidth: 540, minHeight: 420)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in status.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NewFile")
                .font(.system(.largeTitle).weight(.semibold))
            Text("The missing New File button for macOS.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            if !status.extensionEnabled {
                Button("Refresh status", action: status.refresh)
                    .buttonStyle(.link)
                    .font(.caption)
            }
            Link("github.com/WheelUpLabs/newfile",
                 destination: URL(string: "https://github.com/WheelUpLabs/newfile")!)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func openExtensionsSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}

// MARK: - Step

private struct PrimaryButton {
    let title: String
    let action: () -> Void
    var prominent: Bool = true
}

private enum StepDescription {
    case path(String)
    case twoLine(primary: String, secondary: String)
}

private enum StepBadgeKind {
    case number(Int, isComplete: Bool)
    case optional
}

private struct StepView: View {
    let badge: StepBadgeKind
    let title: String
    var titlePrefix: String? = nil
    let description: StepDescription
    let primaryButton: PrimaryButton?

    private var isComplete: Bool {
        if case .number(_, let done) = badge { return done }
        return false
    }
    private var isOptional: Bool {
        if case .optional = badge { return true }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            StepBadge(kind: badge)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                titleRow
                descriptionView
                    .fixedSize(horizontal: false, vertical: true)

                if let button = primaryButton {
                    Group {
                        if button.prominent {
                            Button(button.title, action: button.action)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        } else {
                            Button(button.title, action: button.action)
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                        }
                    }
                    .padding(.top, button.prominent ? 10 : 6)
                }
            }
        }
    }

    @ViewBuilder
    private var titleRow: some View {
        if let prefix = titlePrefix {
            VStack(alignment: .leading, spacing: 4) {
                Text(prefix)
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isOptional ? .secondary : .primary)
            }
        } else {
            Text(title)
                .font(.headline)
                .foregroundStyle(isComplete ? .secondary : .primary)
        }
    }

    @ViewBuilder
    private var descriptionView: some View {
        switch description {
        case .path(let text):
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
        case .twoLine(let primary, let secondary):
            VStack(alignment: .leading, spacing: 2) {
                Text(primary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct StepBadge: View {
    let kind: StepBadgeKind

    var body: some View {
        ZStack {
            switch kind {
            case .number(let n, let isComplete):
                Circle()
                    .fill(isComplete ? Color.green : Color.accentColor)
                    .frame(width: 22, height: 22)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(n)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            case .optional:
                // No glyph — let the OPTIONAL label carry hierarchy.
                // Transparent placeholder preserves column alignment with
                // the numbered steps above.
                Color.clear
                    .frame(width: 22, height: 22)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch kind {
        case .number(let n, let done):
            return done ? "Step \(n), complete" : "Step \(n)"
        case .optional:
            return "Optional step"
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 540, height: 420)
}
