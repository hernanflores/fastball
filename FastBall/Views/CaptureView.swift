import SwiftUI

struct CaptureView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "NEW NOTE") { EmptyView() }

            NoteTextView(text: $state.pendingText)

            HintBar(hints: ["⌘↩ save", "ESC discard", "⌘W hide"])
        }
    }
}
