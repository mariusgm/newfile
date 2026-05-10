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

    func addCustomType() {
        let new = FileTypeEntry(
            ext: "",
            baseName: "",
            displayName: "New file",
            template: "",
            enabled: true,
            isBuiltIn: false
        )
        fileTypes.append(new)
        // No persist yet — empty ext is invalid; persist on next valid edit.
    }

    func move(from source: IndexSet, to destination: Int) {
        fileTypes.move(fromOffsets: source, toOffset: destination)
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
                Button("+ Add type…") { vm.addCustomType() }
            }

            List {
                ForEach($vm.fileTypes) { $entry in
                    if !entry.isBuiltIn && isFirstCustom(entry, in: vm.fileTypes) {
                        sectionDivider("your types")
                    }
                    FileTypeRow(
                        entry: $entry,
                        onDelete: entry.isBuiltIn ? nil : { vm.delete(entry) }
                    )
                    .onChange(of: entry) { newValue in
                        if newValue.isBuiltIn || (try? FileTypeEntry.validateExtension(newValue.ext)) != nil {
                            vm.persist()
                        }
                    }
                }
                .onMove { source, dest in vm.move(from: source, to: dest) }
            }
            .listStyle(.plain)
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

    private func isFirstCustom(_ entry: FileTypeEntry, in list: [FileTypeEntry]) -> Bool {
        guard let first = list.first(where: { !$0.isBuiltIn }) else { return false }
        return first.id == entry.id
    }

    private func sectionDivider(_ title: String) -> some View {
        HStack {
            Text("— \(title) —")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, 8)
    }
}

#Preview {
    PreferencesView()
}
