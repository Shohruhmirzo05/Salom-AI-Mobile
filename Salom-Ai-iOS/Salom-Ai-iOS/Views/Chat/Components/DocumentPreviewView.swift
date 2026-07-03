//
//  DocumentPreviewView.swift
//  Salom-Ai-iOS
//
//  In-app document viewer: opens the server-generated PDF *inside* the app
//  (not an immediate share sheet), with Share + Download (save to Files), and a
//  hint to revise via chat.
//

import SwiftUI
import PDFKit
import UIKit

struct PreviewDocument: Identifiable {
    let id = UUID()
    let url: URL
    let isPDF: Bool
}

struct DocumentPreviewView: View {
    let doc: PreviewDocument
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var showSaver = false

    var body: some View {
        NavigationStack {
            Group {
                if doc.isPDF {
                    PDFKitView(url: doc.url)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 52))
                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                        Text(doc.url.lastPathComponent).foregroundColor(.primary)
                        Text("Faylni saqlang yoki ulashing")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Hujjat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showSaver = true } label: { Image(systemName: "square.and.arrow.down") }
                    Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Yoqmadimi? Chatda tahrirlashni yozing")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showShare) { ShareSheet(items: [doc.url]) }
            .sheet(isPresented: $showSaver) { DocumentSaver(url: doc.url) }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document == nil { view.document = PDFDocument(url: url) }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct DocumentSaver: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
}
