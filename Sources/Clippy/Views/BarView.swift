import SwiftUI

struct BarView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                TopBar()
                    .padding(.horizontal, 14)
                CardsRow()   // full-bleed: cards scroll all the way to the glass edge
            }
            .padding(.top, 12)
            .padding(.bottom, 14)

            if model.showSettings || model.showTagCreator {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            model.showSettings = false
                            model.showTagCreator = false
                        }
                    }
            }

            if model.showSettings {
                HStack {
                    Spacer()
                    SettingsCard()
                        .padding(.top, 46)
                        .padding(.trailing, 18)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }

            if model.showTagCreator {
                TagCreatorCard()
                    .padding(.top, 48)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: model.showSettings)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: model.showTagCreator)
        .environment(\.colorScheme, model.isDarkMode ? .dark : .light)
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            HStack(spacing: 6) {
                SearchControl()
                AllClipsChip()
                ForEach(model.store.tags) { tag in
                    TagChipView(tag: tag)
                }
                NewTagButton()
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Spacer()
                if !model.multiSelection.isEmpty {
                    MultiCopyPill()
                }
                SettingsButton()
            }
        }
        .frame(height: 36)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: model.multiSelection.isEmpty)
    }
}

private struct SearchControl: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if model.searchActive {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("Search everything…", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                        .focused($focused)
                        .frame(width: 190)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            model.searchText = ""
                            model.searchActive = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Theme.tone.opacity(0.10)))
                .overlay(Capsule().strokeBorder(Theme.tone.opacity(0.20), lineWidth: 1))
                .onAppear { focused = true }
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { model.searchActive = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight(Circle())
                .help("Search clipboard")
            }
        }
        .onChange(of: model.searchText) { _, _ in model.selectedIndex = 0 }
    }
}

private struct AllClipsChip: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ChipButton(selected: model.selectedTagID == nil) {
            model.selectedTagID = nil
            model.selectedIndex = 0
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                Text("Clipboard")
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }
}

private struct TagChipView: View {
    @EnvironmentObject var model: AppModel
    let tag: ClipTag

    var body: some View {
        ChipButton(selected: model.selectedTagID == tag.id) {
            model.selectedTagID = model.selectedTagID == tag.id ? nil : tag.id
            model.selectedIndex = 0
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 8, height: 8)
                Text(tag.name)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                model.store.deleteTag(tag)
                if model.selectedTagID == tag.id { model.selectedTagID = nil }
            } label: {
                Label("Delete Tag \"\(tag.name)\"", systemImage: "trash")
            }
        }
    }
}

private struct ChipButton<Label: View>: View {
    var selected: Bool
    var action: () -> Void
    @ViewBuilder var label: () -> Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label()
                .foregroundStyle(selected ? Theme.textPrimary : Theme.textPrimary.opacity(0.85))
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(
                    Capsule().fill(
                        selected ? Theme.chipSelectedFill
                                 : Theme.tone.opacity(hovering ? 0.12 : 0)
                    )
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Theme.chipSelectedStroke : .clear, lineWidth: 1)
                )
                .shadow(color: selected && !Theme.isDark ? .black.opacity(0.07) : .clear, radius: 1.5, y: 0.5)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
        }
    }
}

private struct NewTagButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { model.showTagCreator.toggle() }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(Circle())
        .help("New tag")
    }
}

private struct MultiCopyPill: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Button {
                model.copyMultiSelection()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Copy \(model.multiSelection.count) item\(model.multiSelection.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(Capsule().fill(Theme.accent))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Copy all selected clips together (↩)")

            Button {
                withAnimation(.easeOut(duration: 0.15)) { model.multiSelection = [] }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight(Circle())
            .help("Clear selection")
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

private struct SettingsButton: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { model.showSettings.toggle() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(Circle())
        .help("Settings")
    }
}

// MARK: - Cards row

private struct CardsRow: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let clips = model.filteredClips
        Group {
            if clips.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                                ClipCardView(clip: clip,
                                             isSelected: index == model.selectedIndex)
                                    .id(clip.id)
                                    .onDrag { model.dragProvider(for: clip) }
                                    .onTapGesture {
                                        if NSEvent.modifierFlags.contains(.shift) {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                                model.toggleMultiSelect(clip)
                                            }
                                        } else {
                                            model.selectedIndex = index
                                            model.copyToPasteboard(clip)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: model.selectedIndex) { _, newValue in
                        guard clips.indices.contains(newValue) else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(clips[newValue].id, anchor: nil)
                        }
                    }
                }
            }
        }
        .frame(height: Theme.cardHeight + 20)
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: model.searchText.isEmpty ? "paperclip" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.textSecondary)
            Text(model.searchText.isEmpty
                 ? (model.selectedTagID == nil ? "Nothing here yet — copy something!" : "No clips saved to this tag yet")
                 : "No results for “\(model.searchText)”")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
