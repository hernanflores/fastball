import AppKit
import SwiftUI

/// The palette the CSS variables in index.html used to define, moved onto
/// semantic AppKit colors so the panel follows the system appearance instead of
/// being hardcoded dark.
enum Theme {
    static let accent = Color.accentColor
    static let text = Color(nsColor: .labelColor)
    static let dim = Color(nsColor: .secondaryLabelColor)
    static let muted = Color(nsColor: .tertiaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)
    static let selection = Color.accentColor.opacity(0.18)

    static let cornerRadius: CGFloat = 12
    static let ui = Font.system(size: 12)
    static let uiMedium = Font.system(size: 12, weight: .medium)
    static let label = Font.system(size: 10, weight: .semibold).monospaced()
    static let mono = Font.system(size: 12).monospaced()
    static let monoSmall = Font.system(size: 11).monospaced()
}

/// Translucent panel material, replacing the flat #1a1a1a fill.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Shared header row: a title on the left, optional trailing content.
struct PanelHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.label)
                .kerning(1.2)
                .foregroundStyle(Theme.dim)
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.separator).frame(height: 1)
        }
    }
}

/// The footer hint line ("ESC back · ⌘O open · …").
struct HintBar: View {
    let hints: [String]

    var body: some View {
        Text(hints.joined(separator: "  ·  "))
            .font(.system(size: 10).monospaced())
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(height: 26)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.separator).frame(height: 1)
            }
    }
}
