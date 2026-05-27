//
//  NSPasteboardTests.swift
//  GhosttyTests
//
//  Tests for NSPasteboard.PasteboardType MIME type conversion.
//

import Testing
import AppKit
@testable import Ghostty

struct NSPasteboardTypeExtensionTests {
    private func makeTestPNGData() throws -> Data {
        try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
        ))
    }

    /// Test text/plain MIME type converts to .string
    @Test func testTextPlainMimeType() async throws {
        let pasteboardType = NSPasteboard.PasteboardType(mimeType: "text/plain")
        #expect(pasteboardType != nil)
        #expect(pasteboardType == .string)
    }

    /// Test text/html MIME type converts to .html
    @Test func testTextHtmlMimeType() async throws {
        let pasteboardType = NSPasteboard.PasteboardType(mimeType: "text/html")
        #expect(pasteboardType != nil)
        #expect(pasteboardType == .html)
    }

    /// Test image/png MIME type
    @Test func testImagePngMimeType() async throws {
        let pasteboardType = NSPasteboard.PasteboardType(mimeType: "image/png")
        #expect(pasteboardType != nil)
        #expect(pasteboardType == .png)
    }

    @Test func opinionatedStringContentsMaterializesClipboardImage() throws {
        let pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setData(try makeTestPNGData(), forType: .png)

        let contents = try #require(pasteboard.getOpinionatedStringContents())
        #expect(contents.hasSuffix(".png"))

        let path = contents.replacingOccurrences(of: "\\ ", with: " ")
        #expect(FileManager.default.fileExists(atPath: path))
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test func opinionatedStringContentsPrefersTextOverClipboardImage() throws {
        let pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setData(try makeTestPNGData(), forType: .png)
        pasteboard.setString("plain text", forType: .string)

        #expect(pasteboard.getOpinionatedStringContents() == "plain text")
    }
}
