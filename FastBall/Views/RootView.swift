import SwiftUI

struct RootView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            VisualEffectBackground()
            content
        }
        .frame(width: 400, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch state.route {
        case .list:     ListView(state: state)
        case .editor:   EditorView(state: state)
        case .capture:  CaptureView(state: state)
        case .settings: SettingsView(state: state)
        }
    }
}
