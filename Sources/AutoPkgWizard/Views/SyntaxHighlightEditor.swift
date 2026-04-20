import AppKit
import Highlightr
import SwiftUI

/// A SwiftUI wrapper around NSTextView with Highlightr syntax highlighting.
/// Supports editing and re-highlights on text changes.
struct SyntaxHighlightEditor: NSViewRepresentable {
    @Binding var text: String
    let language: String // "xml" for plist, "yaml" for yaml

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.currentLanguage = language
        context.coordinator.setupHighlightr()
        context.coordinator.applyHighlighting(text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update the parent reference so the coordinator sees the latest language
        context.coordinator.parent = self

        // Only update if the text or language has changed externally (not from user editing)
        if context.coordinator.isUpdating { return }
        let currentText = textView.string
        let languageChanged = context.coordinator.currentLanguage != language
        if currentText != text || languageChanged {
            context.coordinator.currentLanguage = language
            context.coordinator.applyHighlighting(text)
        }
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightEditor
        var textView: NSTextView?
        var highlightr: Highlightr?
        var isUpdating = false
        var currentLanguage: String = ""

        // Debounce work item for re-highlighting
        private var highlightWork: DispatchWorkItem?

        init(_ parent: SyntaxHighlightEditor) {
            self.parent = parent
        }

        func setupHighlightr() {
            highlightr = Highlightr()
            // Use a theme that works well on both light and dark backgrounds
            highlightr?.setTheme(to: "xcode")
        }

        func applyHighlighting(_ text: String) {
            guard let textView = textView else { return }

            isUpdating = true
            defer { isUpdating = false }

            let selectedRanges = textView.selectedRanges

            if let highlightr = highlightr,
               let attributed = highlightr.highlight(text, as: parent.language) {
                // Preserve the font size
                let mutable = NSMutableAttributedString(attributedString: attributed)
                let fullRange = NSRange(location: 0, length: mutable.length)
                mutable.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)
                textView.textStorage?.setAttributedString(mutable)
            } else {
                textView.string = text
            }

            // Restore selection
            textView.selectedRanges = selectedRanges
        }

        nonisolated func textDidChange(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let textView = self.textView, !self.isUpdating else { return }

                let newText = textView.string
                self.parent.text = newText

                // Debounce re-highlighting
                self.highlightWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.applyHighlighting(newText)
                }
                self.highlightWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
        }
    }
}

/// Detect file type from override file name
enum OverrideFileType {
    case plist
    case yaml
    case unknown

    init(fileName: String) {
        if fileName.hasSuffix(".recipe.yaml") {
            self = .yaml
        } else if fileName.hasSuffix(".recipe.plist") || fileName.hasSuffix(".recipe") {
            self = .plist
        } else {
            // Try to detect from content later; default to plist
            self = .unknown
        }
    }

    /// The Highlightr language identifier
    var highlightrLanguage: String {
        switch self {
        case .plist: return "xml"
        case .yaml: return "yaml"
        case .unknown: return "xml"
        }
    }

    /// Detect type from file content if the extension was ambiguous
    static func detect(fileName: String, content: String) -> OverrideFileType {
        let fromName = OverrideFileType(fileName: fileName)
        if fromName != .unknown { return fromName }

        // Heuristic: if content starts with "<?xml" or "<" it's plist XML
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<") {
            return .plist
        }
        // Otherwise assume YAML
        return .yaml
    }
}
