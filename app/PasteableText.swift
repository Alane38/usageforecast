import AppKit
import SwiftUI

/// Zone de texte dont les raccourcis ⌘V, ⌘C, ⌘X et ⌘A fonctionnent toujours : dans une app de barre de menu
/// sans menu « Édition », ces combinaisons n'atteindraient jamais le champ.
final class PasteableNSTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        runEditingShortcut(for: event) || super.performKeyEquivalent(with: event)
    }

    private func runEditingShortcut(for event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let key = event.charactersIgnoringModifiers,
              let action = editingShortcuts[key] else { return false }
        action()
        return true
    }

    private var editingShortcuts: [String: () -> Void] {
        [
            "v": { self.paste(nil) },
            "c": { self.copy(nil) },
            "x": { self.cut(nil) },
            "a": { self.selectAll(nil) },
        ]
    }
}

/// Champ multiligne avec retour à la ligne automatique, pour coller un cookie ou un long jeton.
struct PasteableTextField {
    @Binding var text: String
    /// Conservé pour les appelants ; `NSTextView` n'affiche pas de texte indicatif.
    let placeholder: String

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let owner: PasteableTextField

        init(owner: PasteableTextField) {
            self.owner = owner
        }

        func textDidChange(_ notification: Notification) {
            guard let edited = notification.object as? NSTextView else { return }
            owner.text = edited.string
        }
    }

    private func makeEditor(delegate: NSTextViewDelegate) -> PasteableNSTextView {
        let editor = PasteableNSTextView()
        editor.delegate = delegate
        editor.font = .systemFont(ofSize: 11)
        editor.textColor = .labelColor
        editor.backgroundColor = .textBackgroundColor
        editor.drawsBackground = true
        editor.textContainerInset = NSSize(width: 4, height: 4)

        editor.isEditable = true
        editor.isSelectable = true
        editor.isRichText = false
        editor.allowsUndo = true
        editor.usesFindBar = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false

        // Le texte passe à la ligne à la largeur du champ et ne grandit que vers le bas.
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        return editor
    }
}

extension PasteableTextField: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let container = NSScrollView()
        container.documentView = makeEditor(delegate: context.coordinator)
        container.hasVerticalScroller = true
        container.hasHorizontalScroller = false
        container.autohidesScrollers = true
        container.borderType = .bezelBorder
        return container
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let editor = nsView.documentView as? PasteableNSTextView, editor.string != text else { return }
        editor.string = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }
}
