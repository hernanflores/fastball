import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    @State private var notesFolder: String = ""
    @State private var globalShortcut: String = ""
    @State private var preferredEditor: String = ""
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "SETTINGS") { EmptyView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Notes folder", text: $notesFolder, browse: .directory)
                    field("Global shortcut", text: $globalShortcut, browse: nil,
                          hint: "Electron-style accelerator, e.g. Ctrl+Cmd+,")
                    field("Preferred editor", text: $preferredEditor, browse: .file,
                          hint: "Leave empty to use the system default")

                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .font(Theme.ui)
                        .onChange(of: launchAtLogin) { _, enabled in
                            state.setLaunchAtLogin(enabled)
                            launchAtLogin = state.launchesAtLogin
                        }

                    if let error = state.settingsError {
                        Text(error)
                            .font(Theme.monoSmall)
                            .foregroundStyle(.red)
                    }

                    Button("Save") {
                        _ = state.saveConfig(notesFolder: notesFolder,
                                             globalShortcut: globalShortcut,
                                             preferredEditor: preferredEditor)
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(14)
            }

            HintBar(hints: ["ESC back", "⌘W hide"])
        }
        .onAppear {
            notesFolder = state.config.notesFolder
            globalShortcut = state.config.globalShortcut
            preferredEditor = state.config.preferredEditor
            launchAtLogin = state.launchesAtLogin
        }
    }

    private enum BrowseKind { case file, directory }

    @ViewBuilder
    private func field(_ title: String, text: Binding<String>,
                       browse: BrowseKind?, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(Theme.label)
                .kerning(1.0)
                .foregroundStyle(Theme.dim)

            HStack(spacing: 6) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.monoSmall)

                if let browse {
                    Button("Browse…") { runOpenPanel(kind: browse, into: text) }
                }
            }

            if let hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func runOpenPanel(kind: BrowseKind, into text: Binding<String>) {
        state.setDialogOpen(true)
        let panel = NSOpenPanel()
        panel.canChooseFiles = (kind == .file)
        panel.canChooseDirectories = (kind == .directory)
        panel.canCreateDirectories = (kind == .directory)
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            text.wrappedValue = url.path
        }
        state.setDialogOpen(false)
    }
}
