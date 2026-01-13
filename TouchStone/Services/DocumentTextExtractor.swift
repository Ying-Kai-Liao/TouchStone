import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Service for extracting text content from various document formats.
/// Used to provide document context for AI-assisted plan refinement.
actor DocumentTextExtractor {

    // MARK: - Errors

    enum ExtractionError: LocalizedError {
        case unsupportedFileType(String)
        case accessDenied
        case extractionFailed(String)
        case fileMoved

        var errorDescription: String? {
            switch self {
            case .unsupportedFileType(let ext):
                return "File type '\(ext)' is not supported. Try PDF, TXT, or RTF files."
            case .accessDenied:
                return "Unable to access this file. Please try selecting it again."
            case .extractionFailed(let reason):
                return "Could not extract text from this file: \(reason)"
            case .fileMoved:
                return "This file has been moved or deleted."
            }
        }
    }

    // MARK: - Supported Types

    /// File extensions that can be processed
    static let supportedExtensions: Set<String> = ["pdf", "txt", "text", "rtf", "rtfd", "md", "markdown"]

    /// Check if a file extension is supported
    static func isSupported(_ extension: String) -> Bool {
        supportedExtensions.contains(`extension`.lowercased())
    }

    // MARK: - Main Extraction

    /// Extract text content from a file URL
    func extractText(from url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()

        guard DocumentTextExtractor.isSupported(fileExtension) else {
            throw ExtractionError.unsupportedFileType(fileExtension)
        }

        // Start accessing security-scoped resource if needed
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.fileMoved
        }

        switch fileExtension {
        case "pdf":
            return try extractPDFText(from: url)
        case "txt", "text", "md", "markdown":
            return try extractPlainText(from: url)
        case "rtf", "rtfd":
            return try extractRTFText(from: url)
        default:
            throw ExtractionError.unsupportedFileType(fileExtension)
        }
    }

    /// Extract text from a ProjectDocument using its bookmark
    func extractText(from document: ProjectDocument) async throws -> String {
        guard let url = document.resolveBookmark() else {
            throw ExtractionError.fileMoved
        }

        return try await extractText(from: url)
    }

    // MARK: - PDF Extraction

    private func extractPDFText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ExtractionError.extractionFailed("Could not open PDF document")
        }

        var textParts: [String] = []

        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.string {
                let trimmed = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    textParts.append(trimmed)
                }
            }
        }

        guard !textParts.isEmpty else {
            throw ExtractionError.extractionFailed("PDF contains no extractable text (may be scanned/image-based)")
        }

        return textParts.joined(separator: "\n\n")
    }

    // MARK: - Plain Text Extraction

    private func extractPlainText(from url: URL) throws -> String {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else {
                throw ExtractionError.extractionFailed("File is empty")
            }

            return trimmed
        } catch let error as ExtractionError {
            throw error
        } catch {
            throw ExtractionError.extractionFailed(error.localizedDescription)
        }
    }

    // MARK: - RTF Extraction

    private func extractRTFText(from url: URL) throws -> String {
        do {
            let data = try Data(contentsOf: url)

            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtf
            ]

            let attributedString = try NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )

            let text = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                throw ExtractionError.extractionFailed("RTF file is empty")
            }

            return text
        } catch let error as ExtractionError {
            throw error
        } catch {
            throw ExtractionError.extractionFailed(error.localizedDescription)
        }
    }

    // MARK: - Utilities

    /// Truncate text to a maximum length for AI context (to avoid token limits)
    func truncateForContext(_ text: String, maxCharacters: Int = 50000) -> String {
        guard text.count > maxCharacters else { return text }

        let truncated = String(text.prefix(maxCharacters))

        // Try to end at a sentence boundary
        if let lastPeriod = truncated.lastIndex(of: ".") {
            return String(truncated[...lastPeriod]) + "\n\n[Document truncated for length]"
        }

        return truncated + "\n\n[Document truncated for length]"
    }
}
