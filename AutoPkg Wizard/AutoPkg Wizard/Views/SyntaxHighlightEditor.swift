import AppKit
import Highlightr
import SwiftUI

/// Manages the user's preferred syntax highlighting themes.
/// Automatically adapts to light/dark mode with separate theme preferences.
@MainActor
@Observable
final class SyntaxThemeManager {
    static let shared = SyntaxThemeManager()

    private static let lightThemeKey = "syntaxThemeLight"
    private static let darkThemeKey = "syntaxThemeDark"

    var lightTheme: String {
        didSet { UserDefaults.standard.set(lightTheme, forKey: Self.lightThemeKey) }
    }

    var darkTheme: String {
        didSet { UserDefaults.standard.set(darkTheme, forKey: Self.darkThemeKey) }
    }

    /// Cached list of available Highlightr themes
    let availableThemes: [String]

    /// Common dark themes suitable for dark mode
    static let recommendedDarkThemes: Set<String> = [
        "atom-one-dark", "dracula", "monokai", "vs2015",
        "tomorrow-night", "github-dark", "nord", "ocean",
        "zenburn", "solarized-dark", "gruvbox-dark",
    ]

    /// Common light themes suitable for light mode
    static let recommendedLightThemes: Set<String> = [
        "xcode", "atom-one-light", "github", "vs",
        "tomorrow", "solarized-light", "gruvbox-light",
    ]

    private init() {
        self.lightTheme = UserDefaults.standard.string(forKey: Self.lightThemeKey) ?? "xcode"
        self.darkTheme = UserDefaults.standard.string(forKey: Self.darkThemeKey) ?? "atom-one-dark"
        self.availableThemes = Highlightr()?.availableThemes().sorted() ?? []
    }

    /// Returns the appropriate theme for the current system appearance
    func currentTheme(for appearance: NSAppearance?) -> String {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? darkTheme : lightTheme
    }
}

/// A SwiftUI wrapper around NSTextView with Highlightr syntax highlighting.
/// Supports editing and re-highlights on text changes.
struct SyntaxHighlightEditor: NSViewRepresentable {
    @Binding var text: String
    let language: String // "xml" for plist, "yaml" for yaml
    let themeName: String

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
        context.coordinator.currentTheme = themeName
        context.coordinator.setupHighlightr()
        context.coordinator.applyHighlighting(text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.parent = self

        if context.coordinator.isUpdating { return }
        let currentText = textView.string
        let languageChanged = context.coordinator.currentLanguage != language
        let themeChanged = context.coordinator.currentTheme != themeName
        if currentText != text || languageChanged || themeChanged {
            context.coordinator.currentLanguage = language
            context.coordinator.currentTheme = themeName
            context.coordinator.setupHighlightr()
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
        var currentTheme: String = ""
        private var highlightWork: DispatchWorkItem?

        init(_ parent: SyntaxHighlightEditor) {
            self.parent = parent
        }

        func setupHighlightr() {
            if highlightr == nil {
                highlightr = Highlightr()
            }
            highlightr?.setTheme(to: currentTheme)
        }

        func applyHighlighting(_ text: String) {
            guard let textView = textView else { return }

            isUpdating = true
            defer { isUpdating = false }

            let selectedRanges = textView.selectedRanges

            if let highlightr = highlightr,
               let attributed = highlightr.highlight(text, as: parent.language) {
                let mutable = NSMutableAttributedString(attributedString: attributed)
                let fullRange = NSRange(location: 0, length: mutable.length)
                mutable.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)
                textView.textStorage?.setAttributedString(mutable)

                // Apply theme background color to the text view
                if let bgColor = highlightr.theme?.themeBackgroundColor {
                    textView.backgroundColor = bgColor
                }
            } else {
                textView.string = text
            }

            textView.selectedRanges = selectedRanges
        }

        nonisolated func textDidChange(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let textView = self.textView, !self.isUpdating else { return }

                let newText = textView.string
                self.parent.text = newText

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
            self = .unknown
        }
    }

    var highlightrLanguage: String {
        switch self {
        case .plist: return "xml"
        case .yaml: return "yaml"
        case .unknown: return "xml"
        }
    }

    static func detect(fileName: String, content: String) -> OverrideFileType {
        let fromName = OverrideFileType(fileName: fileName)
        if fromName != .unknown { return fromName }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<") {
            return .plist
        }
        return .yaml
    }
}
