import SwiftUI

struct TemplateEditorSheet: View {
    let extLabel: String
    @Binding var template: String

    @State private var buffer: String
    @Environment(\.dismiss) private var dismiss

    init(extLabel: String, template: Binding<String>) {
        self.extLabel = extLabel
        self._template = template
        self._buffer = State(initialValue: template.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template — .\(extLabel)").font(.headline)
            TextEditor(text: $buffer)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .frame(minHeight: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.separator, lineWidth: 1)
                )
            Text("Plain text. Saved as the file's content.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("OK") {
                    template = buffer
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440, height: 320)
    }
}
