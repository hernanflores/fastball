import AppKit
import SwiftUI

/// An NSTextView wrapper rather than SwiftUI's TextEditor: the app is entirely
/// keyboard-driven, so it needs deterministic first-responder handling and a
/// caret parked at the end of the seeded text (the old capture view's behavior).
struct NoteTextView: NSViewRepresentable {
    @Binding var text: String
    var focusOnAppear: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isVerticallyResizable = true

        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = true

        if focusOnAppear {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
            }
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let location = min(selected.location, text.count)
            textView.setSelectedRange(NSRange(location: location, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: NoteTextView

        init(_ parent: NoteTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
