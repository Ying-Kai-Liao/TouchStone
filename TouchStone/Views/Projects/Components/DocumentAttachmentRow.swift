import SwiftUI
import SwiftData

/// Row displaying an attached document with its extraction status.
struct DocumentAttachmentRow: View {
    let document: ProjectDocument
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: document.iconName)
                .font(.title2)
                .foregroundStyle(UserPreferences.shared.accentColor)
                .frame(width: 32)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(document.filename)
                    .font(.subheadline)
                    .lineLimit(1)

                // Extraction status
                HStack(spacing: 4) {
                    if document.hasExtractedText {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Text extracted")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Pending extraction")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            // Delete button
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Document Picker Row

/// Row for adding a new document (used in document picker section)
struct AddDocumentRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(UserPreferences.shared.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Document")
                        .font(.subheadline)

                    Text("PDF, TXT, RTF, or Markdown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    List {
        DocumentAttachmentRow(
            document: {
                let doc = ProjectDocument(filename: "Project_Spec.pdf", fileType: "com.adobe.pdf")
                doc.extractedText = "Sample extracted text"
                return doc
            }(),
            onDelete: {}
        )

        DocumentAttachmentRow(
            document: ProjectDocument(filename: "Notes.txt", fileType: "public.plain-text"),
            onDelete: {}
        )

        AddDocumentRow(action: {})
    }
    .modelContainer(for: ProjectDocument.self, inMemory: true)
}
