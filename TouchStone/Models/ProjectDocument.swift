import Foundation
import SwiftData

// MARK: - Project Document Model

/// A ProjectDocument represents a file attached to a project for planning context.
/// Documents can be PDFs, text files, or other supported formats that provide
/// additional context for AI-assisted plan refinement.
@Model
final class ProjectDocument {
    var id: UUID
    var filename: String                  // Original filename
    var fileType: String                  // UTType identifier (e.g., "com.adobe.pdf")
    var bookmarkData: Data?               // Security-scoped bookmark for file access
    var extractedText: String?            // Cached text extraction for AI context
    var createdAt: Date

    var project: Project?

    init(
        id: UUID = UUID(),
        filename: String,
        fileType: String,
        bookmarkData: Data? = nil,
        extractedText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filename = filename
        self.fileType = fileType
        self.bookmarkData = bookmarkData
        self.extractedText = extractedText
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// Whether text has been successfully extracted from this document
    var hasExtractedText: Bool {
        extractedText != nil && !(extractedText?.isEmpty ?? true)
    }

    /// File extension derived from filename
    var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    /// Icon name for this document type
    var iconName: String {
        switch fileExtension {
        case "pdf":
            return "doc.text.fill"
        case "txt", "text":
            return "doc.plaintext"
        case "rtf", "rtfd":
            return "doc.richtext"
        case "md", "markdown":
            return "doc.text"
        default:
            return "doc"
        }
    }

    // MARK: - File Access

    /// Resolve the bookmark to get the file URL
    /// Note: On iOS, bookmarks work differently than macOS
    func resolveBookmark() -> URL? {
        guard let bookmarkData = bookmarkData else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, file may have been moved
                return nil
            }

            return url
        } catch {
            return nil
        }
    }

    /// Create a bookmark from a URL
    /// Note: On iOS, we use minimal bookmarks which work within the app sandbox
    static func createBookmark(from url: URL) -> Data? {
        do {
            // Start accessing the resource if security-scoped
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            return bookmarkData
        } catch {
            return nil
        }
    }
}
