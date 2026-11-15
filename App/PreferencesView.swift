import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var fileTypes: [FileTypeEntry]
    @Published var useRightClickSubmenu: Bool {
        didSet { store?.useRightClickSubmenu = useRightClickSubmenu }
    }

    private let store: SettingsStore?
    private var persistCancellable: AnyCancellable?

    init(store: SettingsStore? = SettingsStore.appGroupStore()) {
        self.store = store
        self.fileTypes = store?.fileTypes ?? SeedPresets.builtIns
        self.useRightClickSubmenu = store?.useRightClickSubmenu ?? false

        // Persist off a debounce, not per keystroke: every edit used to JSON-encode
        // the full list into UserDefaults synchronously from the row's onChange.
        persistCancellable = $fileTypes
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [store] types in
                store?.fileTypes = Self.validOnly(types)
            }
    }

    /// Rows with an invalid extension stay visible in the UI but never reach
    /// the store (the extension would render them in the Finder menu).
    nonisolated private static func validOnly(_ types: [FileTypeEntry]) -> [FileTypeEntry] {
        types.filter { $0.isBuiltIn || (try? FileTypeEntry.validateExtension($0.ext)) != nil }
    }

    func persist() {
        store?.fileTypes = Self.validOnly(fileTypes)
    }

    func delete(_ entry: FileTypeEntry) {
        fileTypes.removeAll { $0.id == entry.id }
        persist()
    }

    func addCustomType() {
        let new = FileTypeEntry(
            ext: "",
            baseName: "",
            displayName: "",  // blank -> menuTitle derives from ext
            template: "",
            enabled: true,
            isBuiltIn: false
        )
        fileTypes.append(new)
    }
}

struct PreferencesView: View {
    @StateObject private var vm = PreferencesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var draggingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("File Types").font(.headline)
                Spacer()
                Button("+ Add Type…") { vm.addCustomType() }
            }

            columnHeaders

            // Plain ScrollView, not List: the NSTableView row machinery behind
            // List added first-click latency on the row text fields.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($vm.fileTypes) { $entry in
                        if !entry.isBuiltIn && isFirstCustom(entry, in: vm.fileTypes) {
                            sectionHeader("Custom Types")
                        }
                        FileTypeRow(
                            entry: $entry,
                            onDelete: entry.isBuiltIn ? nil : { vm.delete(entry) },
                            onReorderDrag: {
                                draggingID = entry.id
                                return NSItemProvider(object: entry.id.uuidString as NSString)
                            }
                        )
                        .padding(.horizontal, 8)
                        .onDrop(of: [.text],
                                delegate: RowReorderDelegate(item: entry,
                                                             list: $vm.fileTypes,
                                                             draggingID: $draggingID))
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minHeight: 320, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            Toggle("Group enabled types in a submenu", isOn: $vm.useRightClickSubmenu)
            Text("When off, each enabled type appears directly in the Finder menu.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") {
                    vm.persist()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 660, minHeight: 560)
        .background(InitialFocusClearer())
    }

    /// Column captions for the row fields. Mirrors FileTypeRow's fixed widths
    /// so the captions line up; "enabled" spans the handle + toggle columns.
    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Text("Enabled")
                .frame(width: FileTypeRow.handleColumnWidth + 8 + FileTypeRow.toggleColumnWidth,
                       alignment: .trailing)
                .help("Checked types appear in the Finder menu")
            Text("Extension")
                .frame(width: 110, alignment: .leading)
            Text("Menu Label")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Default Filename")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Template")
                .frame(width: FileTypeRow.templateColumnWidth)
            Color.clear.frame(width: FileTypeRow.deleteColumnWidth + 4, height: 1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.bottom, -6)
    }

    private func isFirstCustom(_ entry: FileTypeEntry, in list: [FileTypeEntry]) -> Bool {
        guard let first = list.first(where: { !$0.isBuiltIn }) else { return false }
        return first.id == entry.id
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 2)
            .padding(.horizontal, 8)
    }
}

/// Moves the dragged row as the cursor passes over other rows; the drop
/// itself just clears the drag state.
private struct RowReorderDelegate: DropDelegate {
    let item: FileTypeEntry
    @Binding var list: [FileTypeEntry]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != item.id,
              let from = list.firstIndex(where: { $0.id == draggingID }),
              let to = list.firstIndex(where: { $0.id == item.id })
        else { return }
        withAnimation {
            list.move(fromOffsets: IndexSet(integer: from),
                      toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

#Preview {
    PreferencesView()
}

/// Opens Preferences with no text field focused. When the window is shown,
/// its first text field (the .txt menu label) became first responder with all
/// its text selected, so the next keystroke replaced it. This clears that when
/// the view first lands in its window and each time the window is shown again
/// after being closed (SwiftUI reuses the Settings window). Switching apps
/// leaves focus alone; clicking or tabbing into a field works as before.
private struct InitialFocusClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ClearerView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ClearerView: NSView {
        private var reopenedAfterClose = false
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            clearTextFocus(in: window)
            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in self?.reopenedAfterClose = true })
            observers.append(center.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self, weak window] _ in
                guard let self, let window, self.reopenedAfterClose else { return }
                self.reopenedAfterClose = false
                self.clearTextFocus(in: window)
            })
        }

        private func clearTextFocus(in window: NSWindow) {
            DispatchQueue.main.async { [weak window] in
                guard let window, window.firstResponder is NSText else { return }
                window.makeFirstResponder(nil)
            }
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
