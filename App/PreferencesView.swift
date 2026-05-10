import SwiftUI

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var fileTypes: [FileTypeEntry]
    @Published var useRightClickSubmenu: Bool {
        didSet { store?.useRightClickSubmenu = useRightClickSubmenu }
    }

    private let store: SettingsStore?

    init(store: SettingsStore? = SettingsStore.appGroupStore()) {
        self.store = store
        self.fileTypes = store?.fileTypes ?? SeedPresets.builtIns
        self.useRightClickSubmenu = store?.useRightClickSubmenu ?? false
    }

    func persist() {
        store?.fileTypes = fileTypes
    }

    func delete(_ entry: FileTypeEntry) {
        fileTypes.removeAll { $0.id == entry.id }
        persist()
    }
}

struct PreferencesView: View {
    @StateObject private var vm = PreferencesViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("File types").font(.headline)
                Spacer()
                Button("+ Add type…") { /* Task 12 */ }
                    .disabled(true) // enabled in Task 12
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach($vm.fileTypes) { $entry in
                        FileTypeRow(
                            entry: $entry,
                            onDelete: entry.isBuiltIn ? nil : { vm.delete(entry) }
                        )
                        .onChange(of: entry) { _ in vm.persist() }
                        Divider()
                    }
                }
            }
            .frame(minHeight: 320)

            Toggle("Use submenu in right-click menu", isOn: $vm.useRightClickSubmenu)
            Text("(when off: each enabled type is its own row)")
                .font(.caption)
                .foregroundStyle(.tertiary)

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
        .frame(minWidth: 520, minHeight: 560)
    }
}

#Preview {
    PreferencesView()
}
