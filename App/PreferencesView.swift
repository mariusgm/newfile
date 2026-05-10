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

            // Placeholder list — rows arrive in Task 11.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.fileTypes) { entry in
                        HStack {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            Toggle("", isOn: .constant(entry.enabled)).labelsHidden().disabled(true)
                            Text(".\(entry.ext)").font(.system(.body, design: .monospaced))
                            Text("\"\(entry.baseName)\"").foregroundStyle(.secondary)
                            Spacer()
                            Button("Template…") { /* Task 11 */ }.disabled(true)
                        }
                        .padding(.vertical, 4)
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
