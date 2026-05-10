import SwiftUI

struct FileTypeRow: View {
    @Binding var entry: FileTypeEntry
    let onDelete: (() -> Void)?
    @State private var showTemplateEditor = false
    @State private var extError: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)

            Toggle("", isOn: $entry.enabled).labelsHidden()

            extensionField
                .frame(width: 110)

            TextField("base name", text: $entry.baseName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Button("Template…") { showTemplateEditor = true }
                .buttonStyle(.bordered)
                .controlSize(.small)

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Delete this custom type")
            } else {
                // Preserve column alignment with custom rows.
                Color.clear.frame(width: 16, height: 16)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showTemplateEditor) {
            TemplateEditorSheet(extLabel: entry.ext, template: $entry.template)
        }
    }

    @ViewBuilder
    private var extensionField: some View {
        if entry.isBuiltIn {
            HStack(spacing: 0) {
                Text(".").foregroundStyle(.secondary)
                Text(entry.ext)
            }
            .font(.system(.body, design: .monospaced))
        } else {
            HStack(spacing: 2) {
                Text(".").foregroundStyle(.secondary).font(.system(.body, design: .monospaced))
                TextField("ext", text: $entry.ext)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: entry.ext) { newValue in
                        validateAndNormalize(newValue)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(extError == nil ? .clear : .red, lineWidth: 1)
                    )
                    .help(extError ?? "")
            }
        }
    }

    private func validateAndNormalize(_ value: String) {
        do {
            let normalized = try FileTypeEntry.validateExtension(value)
            if normalized != entry.ext {
                entry.ext = normalized
            }
            extError = nil
        } catch let err as FileTypeEntry.ValidationError {
            extError = errorMessage(err)
        } catch {
            extError = "Invalid extension"
        }
    }

    private func errorMessage(_ err: FileTypeEntry.ValidationError) -> String {
        switch err {
        case .empty: return "Extension cannot be empty"
        case .tooLong: return "Extension too long (max 16 chars)"
        case .badCharacters: return "Allowed: a-z, 0-9, . _ -"
        }
    }
}
