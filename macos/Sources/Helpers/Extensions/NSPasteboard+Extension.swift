import AppKit
import GhosttyKit
import UniformTypeIdentifiers

extension NSPasteboard.PasteboardType {
    /// Initialize a pasteboard type from a MIME type string
    init?(mimeType: String) {
        // Explicit mappings for common MIME types
        switch mimeType {
        case "text/plain":
            self = .string
            return
        default:
            break
        }

        // Try to get UTType from MIME type
        guard let utType = UTType(mimeType: mimeType) else {
            // Fallback: use the MIME type directly as identifier
            self.init(mimeType)
            return
        }

        // Use the UTType's identifier
        self.init(utType.identifier)
    }
}

extension NSPasteboard {
    private static let temporaryImageFilenamePrefix = "clipboard-"

    /// The pasteboard to used for Ghostty selection.
    static var ghosttySelection: NSPasteboard = {
        NSPasteboard(name: .init("com.mitchellh.ghostty.selection"))
    }()

    /// Gets the contents of the pasteboard as a string following a specific set of semantics.
    /// Does these things in order:
    /// - Tries to get the absolute filesystem path of the file in the pasteboard if there is one and ensures the file path is properly escaped.
    /// - Tries to get any string from the pasteboard.
    /// - Tries to save image data to a temporary file and returns the escaped path.
    /// If all of the above fail, returns None.
    func getOpinionatedStringContents() -> String? {
        if let urls = readObjects(forClasses: [NSURL.self]) as? [URL],
           urls.count > 0 {
            return urls
                .map { $0.isFileURL ? Ghostty.Shell.escape($0.path) : $0.absoluteString }
                .joined(separator: " ")
        }

        if let string = self.string(forType: .string), !string.isEmpty {
            return string
        }

        return saveClipboardImageIfNeeded().map { Ghostty.Shell.escape($0.path) }
    }

    private func saveClipboardImageIfNeeded() -> URL? {
        guard hasImageData else { return nil }

        let imageData: Data
        if let pngData = data(forType: .png) {
            imageData = pngData
        } else {
            guard let image = NSImage(pasteboard: self),
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }
            imageData = pngData
        }

        let fileURL = Self.temporaryImageFileURL()
        do {
            try imageData.write(to: fileURL)
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    private var hasImageData: Bool {
        guard let types else { return false }
        if types.contains(.png) || types.contains(.tiff) {
            return true
        }

        return types.contains { type in
            guard let utType = UTType(type.rawValue) else { return false }
            return utType.conforms(to: .image)
        }
    }

    private static func temporaryImageFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: Date())
        let filename = "\(temporaryImageFilenamePrefix)\(timestamp)-\(UUID().uuidString.prefix(8)).png"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    /// The pasteboard for the Ghostty enum type.
    static func ghostty(_ clipboard: ghostty_clipboard_e) -> NSPasteboard? {
        switch clipboard {
        case GHOSTTY_CLIPBOARD_STANDARD:
            return Self.general

        case GHOSTTY_CLIPBOARD_SELECTION:
            return Self.ghosttySelection

        default:
            return nil
        }
    }
}
