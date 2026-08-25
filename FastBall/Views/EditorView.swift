import SwiftUI

struct EditorView: View {
    @ObservedObject var state: AppState
    @State private var saveTask: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: (state.currentNote?.name ?? "NOTE").uppercased()) {
                EmptyView()
            }

            NoteTextView(text: $state.editorText)

            HintBar(hints: ["ESC back", "⌘O open", "⇧⌘C clear", "⌘W hide"])
        }
        .onChange(of: state.editorText) { _, _ in scheduleSave() }
        .onDisappear { flushSave() }
    }

    /// The 500 ms debounced auto-save from renderer.js.
    private func scheduleSave() {
        saveTask?.cancel()
        let task = DispatchWorkItem { state.saveEditor() }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    private func flushSave() {
        saveTask?.cancel()
        saveTask = nil
        state.saveEditor()
    }
}
