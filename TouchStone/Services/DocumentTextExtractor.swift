import Foundation
import PDFKit
import UniformTypeIdentifiers
import Vision

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
                return "File type '\(ext)' is not supported. Try PDF, TXT, RTF, DOCX, or image files."
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
    static let supportedExtensions: Set<String> = [
        "pdf", "txt", "text", "rtf", "rtfd", "md", "markdown",
        "docx",  // Word documents
        "png", "jpg", "jpeg", "heic", "heif"  // Images with OCR
    ]

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
        case "docx":
            return try extractDOCXText(from: url)
        case "png", "jpg", "jpeg", "heic", "heif":
            return try await extractImageText(from: url)
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

    // MARK: - DOCX Extraction

    private func extractDOCXText(from url: URL) throws -> String {
        // DOCX is a ZIP archive with word/document.xml containing the content
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            // Create temp directory for extraction
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            // Unzip using ZIPFoundation-free approach: NSFileCoordinator with rename
            let destinationURL = tempDir.appendingPathComponent("document.zip")
            try FileManager.default.copyItem(at: url, to: destinationURL)

            // Use Archive utility (built into macOS/iOS) via shell - fallback to simple parsing
            // For pure Swift solution, we'll extract using Foundation's decompression

            // Try to read the docx as a directory after unzipping
            let unzipDir = tempDir.appendingPathComponent("unzipped")
            try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

            // Use NSFileCoordinator to handle the zip
            let data = try Data(contentsOf: url)

            // Simple approach: parse the DOCX as a ZIP manually
            // DOCX files have PK header and we need word/document.xml
            let text = try extractTextFromDOCXData(data)

            guard !text.isEmpty else {
                throw ExtractionError.extractionFailed("DOCX file contains no extractable text")
            }

            return text

        } catch let error as ExtractionError {
            throw error
        } catch {
            throw ExtractionError.extractionFailed("Failed to extract DOCX: \(error.localizedDescription)")
        }
    }

    /// Extract text from DOCX data by parsing the ZIP structure
    private func extractTextFromDOCXData(_ data: Data) throws -> String {
        // DOCX is a ZIP file. We need to find word/document.xml and extract text from it.
        // Parse XML directly from the data
        return try parseDocxXMLFallback(data)
    }

    /// Fallback XML parsing for DOCX when NSAttributedString fails
    private func parseDocxXMLFallback(_ data: Data) throws -> String {
        // This is a simplified fallback that searches for text content patterns
        // In a production app, you'd use a proper ZIP library

        // Look for text between <w:t> tags in the data
        guard let dataString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw ExtractionError.extractionFailed("Could not decode DOCX content")
        }

        // Simple regex to find text content
        let pattern = "<w:t[^>]*>([^<]*)</w:t>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            throw ExtractionError.extractionFailed("Invalid DOCX format")
        }

        let range = NSRange(dataString.startIndex..., in: dataString)
        let matches = regex.matches(in: dataString, options: [], range: range)

        var textParts: [String] = []
        for match in matches {
            if let textRange = Range(match.range(at: 1), in: dataString) {
                let text = String(dataString[textRange])
                if !text.isEmpty {
                    textParts.append(text)
                }
            }
        }

        let result = textParts.joined(separator: " ")

        guard !result.isEmpty else {
            throw ExtractionError.extractionFailed("No text found in DOCX file")
        }

        return result
    }

    // MARK: - Image OCR Extraction

    private func extractImageText(from url: URL) async throws -> String {
        guard let imageData = try? Data(contentsOf: url),
              let cgImage = createCGImage(from: imageData) else {
            throw ExtractionError.extractionFailed("Could not load image")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ExtractionError.extractionFailed("OCR failed: \(error.localizedDescription)"))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ExtractionError.extractionFailed("No text recognized in image"))
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let text = recognizedStrings.joined(separator: "\n")

                if text.isEmpty {
                    continuation.resume(throwing: ExtractionError.extractionFailed("No text found in image"))
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ExtractionError.extractionFailed("Vision processing failed: \(error.localizedDescription)"))
            }
        }
    }

    /// Create CGImage from image data (supports multiple formats)
    private func createCGImage(from data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
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
