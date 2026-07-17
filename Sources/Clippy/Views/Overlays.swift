import SwiftUI
import ServiceManagement

/// Shared dark glass card chrome for floating overlays (settings, tag creator).
private struct OverlayCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.overlayBody)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.tone.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
    }
}

// MARK: - Settings

struct SettingsCard: View {
    @EnvironmentObject var model: AppModel
    @State private var retention: TimeInterval = ClipStore.defaultRetention
    @State private var maxItems: Int = 500
    @State private var pasteOnClick = true
    @State private var startAtLogin = false
    @State private var appearanceMode = AppModel.AppearanceMode.system
    @State private var confirmingClear = false

    private static let retentionOptions: [(String, TimeInterval)] = [
        ("1 Hour", 3600),
        ("1 Day", 86_400),
        ("3 Days", 3 * 86_400),
        ("1 Week", 7 * 86_400),
        ("2 Weeks", 14 * 86_400),
        ("1 Month", 30 * 86_400),
        ("Forever", 0),
    ]

    private static let maxItemsOptions = [100, 250, 500, 1000]

    private func rowLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12))
            .foregroundStyle(Theme.textPrimary.opacity(0.85))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit Clippy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textPrimary.opacity(0.8))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            // Two columns keep the card short enough to fit inside the bar.
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        rowLabel("Keep history for", "clock")
                        Spacer()
                        Picker("", selection: $retention) {
                            ForEach(Self.retentionOptions, id: \.1) { name, value in
                                Text(name).tag(value)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .onChange(of: retention) { _, newValue in
                            model.store.retention = newValue
                        }
                    }
                    HStack {
                        rowLabel("Maximum items", "tray.full")
                        Spacer()
                        Picker("", selection: $maxItems) {
                            ForEach(Self.maxItemsOptions, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .onChange(of: maxItems) { _, newValue in
                            model.store.maxItems = newValue
                        }
                    }
                    HStack {
                        rowLabel("Appearance", "circle.lefthalf.filled")
                        Spacer()
                        Picker("", selection: $appearanceMode) {
                            ForEach(AppModel.AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .onChange(of: appearanceMode) { _, newValue in
                            model.appearanceMode = newValue
                        }
                    }
                }
                .frame(width: 235)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        rowLabel("Paste on click", "cursorarrow.click.2")
                        Spacer()
                        Toggle("", isOn: $pasteOnClick)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .onChange(of: pasteOnClick) { _, newValue in
                                model.pasteOnClick = newValue
                                if newValue { _ = Paster.isTrusted }
                            }
                    }
                    HStack {
                        rowLabel("Start at login", "power")
                        Spacer()
                        Toggle("", isOn: $startAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .onChange(of: startAtLogin) { _, newValue in
                                if newValue {
                                    try? SMAppService.mainApp.register()
                                } else {
                                    try? SMAppService.mainApp.unregister()
                                }
                            }
                    }
                }
                .frame(width: 190)
            }

            if pasteOnClick && !Paster.isTrusted {
                Text("Paste needs Accessibility permission — System Settings → Privacy & Security.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange.opacity(0.9))
            }

            Divider().overlay(Theme.tone.opacity(0.15))

            HStack {
                if confirmingClear {
                    Text("Clear untagged history?")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                    Button("Clear") {
                        model.store.clearHistory()
                        confirmingClear = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                    Button("Cancel") { confirmingClear = false }
                        .controlSize(.small)
                } else {
                    Button {
                        confirmingClear = true
                    } label: {
                        Label("Clear History…", systemImage: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Spacer()
                Text("⌘1 to toggle · tagged clips are never deleted")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 480)
        .modifier(OverlayCard())
        .onAppear {
            retention = model.store.retention
            maxItems = model.store.maxItems
            pasteOnClick = model.pasteOnClick
            startAtLogin = SMAppService.mainApp.status == .enabled
            appearanceMode = model.appearanceMode
        }
    }
}

// MARK: - Tag creator

struct TagCreatorCard: View {
    @EnvironmentObject var model: AppModel
    @State private var name = ""
    @State private var colorHex = Theme.tagPalette[5]
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Tag")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            TextField("Tag name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 10)
                .frame(width: 220, height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.tone.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.tone.opacity(0.18), lineWidth: 1))
                .focused($nameFocused)
                .onSubmit(create)

            HStack(spacing: 8) {
                ForEach(Theme.tagPalette, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().strokeBorder(Color.white, lineWidth: colorHex == hex ? 2 : 0)
                            )
                            .scaleEffect(colorHex == hex ? 1.15 : 1)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: colorHex)
                }
            }

            HStack {
                Spacer()
                Button("Create", action: create)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: colorHex))
                    .controlSize(.small)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .frame(width: 240)
        .modifier(OverlayCard())
        .onAppear { nameFocused = true }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let tag = model.store.addTag(name: trimmed, colorHex: colorHex)
        model.selectedTagID = tag.id
        name = ""
        withAnimation(.easeOut(duration: 0.15)) { model.showTagCreator = false }
    }
}
