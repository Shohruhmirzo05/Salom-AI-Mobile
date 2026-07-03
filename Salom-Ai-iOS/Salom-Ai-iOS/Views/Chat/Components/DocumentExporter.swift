//
//  DocumentExporter.swift
//  Salom-Ai-iOS
//
//  ChatGPT-style on-demand documents: when the user asks for a file, the AI
//  answer can be exported to PDF / Word / Excel and shared. Free + native.
//

import SwiftUI
internal import UIKit

enum DocFormat: String {
    case pdf, docx, xlsx

    var label: String {
        switch self {
        case .pdf: return "PDF hujjat"
        case .docx: return "Word hujjat"
        case .xlsx: return "Excel jadval"
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .docx: return "doc.text"
        case .xlsx: return "tablecells"
        }
    }
}

enum DocumentExporter {

    /// Detect whether the user asked for a downloadable file, and in which format.
    static func detectFormat(_ text: String) -> DocFormat? {
        let s = text.lowercased()
        func has(_ pattern: String) -> Bool {
            s.range(of: pattern, options: .regularExpression) != nil
        }
        if has(#"(excel|xlsx|xls|spreadsheet|jadval|csv)"#) { return .xlsx }
        if has(#"(word|docx|\.doc)"#) { return .docx }
        if has(#"pdf"#) { return .pdf }
        if has(#"(yuklab ol|yuklab ber|faylga|fayl qilib|hujjat qilib|dokument|скачать)"#) { return .pdf }
        return nil
    }

    /// A short message that just asks to convert the PREVIOUS answer to a file
    /// ("pdf qil", "word formatda ber") — NOT a new document ("cv pdf qil").
    /// Returns the format if so, so the app makes the file from the last answer
    /// instead of asking the AI to rewrite it.
    static func pureFormatConversion(_ text: String) -> DocFormat? {
        let s = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fmt = detectFormat(s) else { return nil }
        let words = s.split(whereSeparator: { $0 == " " || $0 == "\n" })
        guard words.count <= 5 else { return nil }
        // If it names a document type, it's a NEW document request, not a conversion.
        let docNouns = ["cv", "rezyume", "resume", "xat", "ariza", "hisobot",
                        "referat", "taklif", "reja", "maqola", "insho",
                        "letter", "report", "essay"]
        if docNouns.contains(where: { s.contains($0) }) { return nil }
        return fmt
    }

    /// Build the file and present the iOS share sheet.
    static func export(_ text: String, format: DocFormat) {
        let url: URL?
        switch format {
        case .pdf:  url = makePDF(text)
        case .docx: url = makeDoc(text)
        case .xlsx: url = makeCSV(text)
        }
        guard let fileURL = url else { return }
        Task { @MainActor in present(fileURL) }
    }

    // MARK: - Builders

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func htmlBody(_ text: String) -> String {
        "<body style='font-family:-apple-system,Helvetica,Arial;font-size:14px;line-height:1.6;color:#141414'>"
        + escaped(text)
        + "<hr style='margin-top:28px;border:none;border-top:1px solid #eee'>"
        + "<div style='color:#999;font-size:11px'>Salom AI — salom-ai.uz</div></body>"
    }

    private static func makePDF(_ text: String) -> URL? {
        let html = "<html><head><meta charset='utf-8'></head>\(htmlBody(text))</html>"
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 @72dpi
        let printable = page.insetBy(dx: 36, dy: 36)
        renderer.setValue(NSValue(cgRect: page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, nil)
        let pageCount = max(renderer.numberOfPages, 1)
        for i in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return write(data as Data, ext: "pdf")
    }

    private static func makeDoc(_ text: String) -> URL? {
        let html = "<html xmlns:w='urn:schemas-microsoft-com:office:word'><head><meta charset='utf-8'></head>\(htmlBody(text))</html>"
        return write(Data(html.utf8), ext: "doc")
    }

    private static func makeCSV(_ text: String) -> URL? {
        // Pull rows out of a Markdown table ( | a | b | )
        let rows: [String] = text.components(separatedBy: "\n").compactMap { line in
            guard line.contains("|") else { return nil }
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.isEmpty { return nil }
            // skip the |---|---| separator row
            if cells.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0 == "-" || $0 == ":" } }) { return nil }
            return cells.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
        }
        guard !rows.isEmpty else { return nil }
        let csv = "\u{FEFF}" + rows.joined(separator: "\r\n")
        return write(Data(csv.utf8), ext: "csv")
    }

    private static func write(_ data: Data, ext: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("salom-ai.\(ext)")
        do { try data.write(to: url); return url } catch { return nil }
    }

    // MARK: - Present

    @MainActor
    private static func present(_ url: URL) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }

        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        top.present(sheet, animated: true)
    }
}
