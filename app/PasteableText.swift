import SwiftUI
import AppKit

/// Zone de texte dont les raccourcis ⌘C, ⌘X, ⌘V et ⌘A fonctionnent même dans un popover ou une fenêtre
/// sans menu Édition, où AppKit ne les route pas jusqu'à la vue.
private final class ShortcutTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let key = event.charactersIgnoringModifiers,
              let action = editingActions[key] else {
            return super.performKeyEquivalent(with: event)
        }
        action(self)
        return true
    }

    private var editingActions: [String: (ShortcutTextView) -> Void] {
        [
            "v": { $0.paste(nil) },
            "c": { $0.copy(nil) },
            "x": { $0.cut(nil) },
            "a": { $0.selectAll(nil) },
        ]
    }
}

/// Champ multiligne (cookies, jetons) avec retour à la ligne, sans correction ni substitution de texte.
struct PasteableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = makeTextView(delegate: context.coordinator)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? ShortcutTextView, textView.string != text else { return }
        textView.string = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    private func makeTextView(delegate: NSTextViewDelegate) -> ShortcutTextView {
        let textView = ShortcutTextView()
        textView.delegate = delegate
        textView.font = NSFont.systemFont(ofSize: 11)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Le texte passe à la ligne : la largeur suit la vue, la hauteur grandit avec le contenu.
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        return textView
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
