import SwiftUI

struct ListView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "NOTES") {
                Button(action: state.showSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }

            if state.notes.isEmpty {
                Spacer()
                Text("Start typing to create a note")
                    .font(Theme.ui)
                    .foregroundStyle(Theme.muted)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(state.notes.enumerated()), id: \.element.id) { index, note in
                                NoteRow(note: note, isSelected: index == state.selectedIndex)
                                    .id(note.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        state.selectedIndex = index
                                        state.open(note)
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: state.selectedIndex) { _, index in
                        guard state.notes.indices.contains(index) else { return }
                        proxy.scrollTo(state.notes[index].id, anchor: nil)
                    }
                }
            }

            HintBar(hints: ["↑↓ move", "↩ open", "type to capture", "⌘, settings"])
        }
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(isSelected ? Theme.accent : .clear)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.name)
                    .font(Theme.uiMedium)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(note.mtime.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 7)
        .background(isSelected ? Theme.selection : .clear)
    }
}
