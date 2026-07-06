//
//  MarkdownText.swift
//  Salom-Ai-iOS
//
//  Lightweight native Markdown renderer (no external dependency) so AI answers
//  render with headings, bold/italic, lists, code blocks and quotes — matching
//  the web. Inline formatting uses Foundation's AttributedString(markdown:).
//

import SwiftUI
internal import UIKit

enum MDBlock: Identifiable {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case numbered(Int, String)
    case code(String, String?)
    case quote(String)
    case divider

    var id: String {
        switch self {
        case .heading(let l, let t): return "h\(l)-\(t.hashValue)"
        case .paragraph(let t): return "p-\(t.hashValue)"
        case .bullet(let t): return "b-\(t.hashValue)"
        case .numbered(let n, let t): return "n\(n)-\(t.hashValue)"
        case .code(let c, _): return "c-\(c.hashValue)"
        case .quote(let t): return "q-\(t.hashValue)"
        case .divider: return "hr-\(UUID().uuidString)"
        }
    }
}

enum MarkdownParser {
    static func parse(_ text: String) -> [MDBlock] {
        var blocks: [MDBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var paragraph: [String] = []

        func flush() {
            let joined = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { blocks.append(.paragraph(joined)) }
            paragraph = []
        }

        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                flush()
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i]); i += 1
                }
                blocks.append(.code(code.joined(separator: "\n"), lang.isEmpty ? nil : lang))
                i += 1
                continue
            }
            if line.isEmpty { flush(); i += 1; continue }
            if line.hasPrefix("#### ") { flush(); blocks.append(.heading(4, String(line.dropFirst(5)))); i += 1; continue }
            if line.hasPrefix("### ")  { flush(); blocks.append(.heading(3, String(line.dropFirst(4)))); i += 1; continue }
            if line.hasPrefix("## ")   { flush(); blocks.append(.heading(2, String(line.dropFirst(3)))); i += 1; continue }
            if line.hasPrefix("# ")    { flush(); blocks.append(.heading(1, String(line.dropFirst(2)))); i += 1; continue }
            if line == "---" || line == "***" || line == "___" { flush(); blocks.append(.divider); i += 1; continue }
            if line.hasPrefix("> ")    { flush(); blocks.append(.quote(String(line.dropFirst(2)))); i += 1; continue }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flush(); blocks.append(.bullet(String(line.dropFirst(2)))); i += 1; continue
            }
            if let m = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flush()
                let numStr = line[line.startIndex..<m.upperBound].filter { $0.isNumber }
                blocks.append(.numbered(Int(numStr) ?? 1, String(line[m.upperBound...])))
                i += 1; continue
            }
            paragraph.append(raw)
            i += 1
        }
        flush()
        return blocks
    }

    static func inline(_ s: String) -> AttributedString {
        var opts = AttributedString.MarkdownParsingOptions()
        opts.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let a = try? AttributedString(markdown: s, options: opts) { return a }
        return AttributedString(s)
    }
}

struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(MarkdownParser.parse(text)) { block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MDBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(MarkdownParser.inline(content))
                .font(.system(size: level == 1 ? 19 : level == 2 ? 17 : 15.5, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        case .paragraph(let content):
            Text(MarkdownParser.inline(content))
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let content):
            HStack(alignment: .top, spacing: 8) {
                Text("•").foregroundColor(SalomTheme.Colors.accentPrimary).font(.system(size: 15, weight: .bold))
                Text(MarkdownParser.inline(content)).font(.system(size: 15)).foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .numbered(let num, let content):
            HStack(alignment: .top, spacing: 8) {
                Text("\(num).").foregroundColor(SalomTheme.Colors.accentPrimary).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                Text(MarkdownParser.inline(content)).font(.system(size: 15)).foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .code(let code, let lang):
            CodeBlockView(code: code, language: lang)
        case .quote(let content):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(SalomTheme.Colors.accentPrimary.opacity(0.5)).frame(width: 3)
                Text(MarkdownParser.inline(content)).font(.system(size: 15)).italic().foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .divider:
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).padding(.vertical, 2)
        }
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "code").font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation { copied = false } }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 11))
                        Text(copied ? "Nusxalandi" : "Nusxa").font(.system(size: 11))
                    }
                    .foregroundColor(copied ? .green : .white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.05))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(12)
            }
        }
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
    }
}
