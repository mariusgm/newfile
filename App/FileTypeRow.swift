import SwiftUI

struct FileTypeRow: View {
    @Binding var entry: FileTypeEntry
    let onDelete: (() -> Void)?
    /// Supplied by the container; attaches drag-reorder to the handle only,
    /// so drags inside text fields never start a row move.
    let onReorderDrag: (() -> NSItemProvider)?
    /// Set while this row's extension field is invalid and Finder keeps using
    /// the last saved version; names that saved extension.
    var heldSavedExt: String? = nil

    @State private var showTemplateEditor = false
    @State private var extError: String? = nil
    @FocusState private var extFocused: Bool

    static let handleColumnWidth: CGFloat = 20
    static let toggleColumnWidth: CGFloat = 20
    static let templateColumnWidth: CGFloat = 56
    static let deleteColumnWidth: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            fieldsRow
            if let heldSavedExt {
                heldNotice(heldSavedExt)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showTemplateEditor) {
            TemplateEditorSheet(extLabel: entry.ext, template: $entry.template)
        }
        .onAppear {
            // A just-added custom row (no extension yet) is ready to type into.
            // Set on the next run-loop turn: set during onAppear, the request
            // was dropped and focus fell to the window's first text field.
            if !entry.isBuiltIn && entry.ext.isEmpty {
                DispatchQueue.main.async { extFocused = true }
            }
        }
    }

    /// Secondary line aligned with the extension field. Only shown while an
    /// edit is invalid, so the user knows nothing was lost.
    private func heldNotice(_ savedExt: String) -> some View {
        (Text("Finder keeps using ")
         + Text(".\(savedExt)").font(.system(.caption, design: .monospaced))
         + Text(" until this extension is valid."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, Self.handleColumnWidth + 8 + Self.toggleColumnWidth + 8)
    }

    private var fieldsRow: some View {
        HStack(spacing: 8) {
            dragHandle
                .frame(width: Self.handleColumnWidth)

            Toggle("", isOn: $entry.enabled)
                .labelsHidden()
                .frame(width: Self.toggleColumnWidth)
                .disabled(!extIsValid)
                .help(extIsValid ? "Show in the Finder menu"
                                 : "Enter a valid extension first")

            extensionField
                .frame(width: 110, alignment: .leading)

            TextField(
                "menu label",
                text: $entry.displayName,
                prompt: Text(FileTypeEntry.derivedDisplayName(ext: entry.ext))
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .help("Label shown in the Finder menu")

            TextField(
                "filename",
                text: $entry.baseName,
                prompt: Text(entry.ext.isEmpty ? "filename" : ".\(entry.ext)")
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
            .help("Filename for the created file. Blank creates a dotfile.")

            templateButton
                .frame(width: Self.templateColumnWidth)

            deleteColumn
                .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var dragHandle: some View {
        let handle = Image(systemName: "line.3.horizontal")
            .foregroundStyle(.tertiary)
            .help("Drag to reorder")
        if let onReorderDrag {
            handle.onDrag(onReorderDrag)
        } else {
            handle
        }
    }

    private var extIsValid: Bool {
        entry.isBuiltIn || (try? FileTypeEntry.validateExtension(entry.ext)) != nil
    }

    private var templateButton: some View {
        Button(entry.template.isEmpty ? "Add…" : "Edit…") {
            showTemplateEditor = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(entry.template.isEmpty ? nil : Color.accentColor)
        .help(entry.template.isEmpty ? "Add starter template" : "Edit starter template")
    }

    @ViewBuilder
    private var deleteColumn: some View {
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .frame(width: Self.deleteColumnWidth)
            .help("Delete this custom type")
        } else {
            // Built-ins can be disabled but not deleted; keep column alignment.
            Color.clear.frame(width: Self.deleteColumnWidth, height: 16)
        }
    }

    @ViewBuilder
    private var extensionField: some View {
        if entry.isBuiltIn {
            HStack(spacing: 1) {
                Text(".").foregroundStyle(.secondary)
                Text(entry.ext)
            }
            .font(.system(.body, design: .monospaced))
            .padding(.leading, 7)
        } else {
            HStack(spacing: 2) {
                Text(".")
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
                TextField("ext", text: $entry.ext)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($extFocused)
                    .onChange(of: entry.ext) { newValue in
                        validateAndNormalize(newValue)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(extError == nil ? .clear : .red, lineWidth: 1)
                    )
                    .help(extError ?? "File extension (letters, 0-9, . _ -)")
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
        case .badCharacters: return "Allowed: letters, 0-9, . _ -"
        }
    }
}
