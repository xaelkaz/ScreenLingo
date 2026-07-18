import AppKit
import SwiftUI
import Translation

@MainActor
final class TranslationResultModel: ObservableObject {
    enum State {
        case translating
        case translated(String)
        case failed(String)
    }

    let sourceText: String
    @Published var state: State = .translating
    @Published var copied = false
    @Published var detectedSourceLanguage: TranslationLanguage?

    init(sourceText: String) {
        self.sourceText = sourceText
    }

    func translate(using session: TranslationSession) async {
        state = .translating
        do {
            let response = try await session.translate(sourceText)
            let detectedLanguage = TranslationLanguage(localeLanguage: response.sourceLanguage)
            guard !TranslationLanguageCatalog.isExcluded(
                identifier: detectedLanguage.identifier
            ) else {
                state = .failed("The detected source language is not supported by ScreenLingo.")
                return
            }
            detectedSourceLanguage = detectedLanguage
            state = .translated(response.targetText)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        let description = error.localizedDescription
        if description.isEmpty {
            return "The translation could not be completed. Check that the required language models are available."
        }
        return description
    }
}

struct TranslationCardView: View {
    @ObservedObject var model: TranslationResultModel
    let sourceLanguage: TranslationLanguage?
    let targetLanguage: TranslationLanguage
    let showsOriginalText: Bool
    let isLive: Bool
    let shortcutDisplayName: String
    let onClose: () -> Void

    init(
        model: TranslationResultModel,
        sourceLanguage: TranslationLanguage?,
        targetLanguage: TranslationLanguage,
        showsOriginalText: Bool,
        isLive: Bool,
        shortcutDisplayName: String,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.showsOriginalText = showsOriginalText
        self.isLive = isLive
        self.shortcutDisplayName = shortcutDisplayName
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showsOriginalText {
                        textBlock(
                            label: sourceLanguageLabel,
                            text: model.sourceText,
                            color: .secondary,
                            isTarget: false
                        )
                    }

                    switch model.state {
                    case .translating:
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Translating to \(targetLanguage.displayName)…")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                    case .translated(let text):
                        textBlock(
                            label: targetLanguage.uppercaseDisplayName,
                            text: text,
                            color: .primary,
                            isTarget: true
                        )
                        actionRow(for: text)

                    case .failed(let message):
                        failureView(message)
                    }
                }
                .padding(18)
            }
        }
        .frame(width: 480, height: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .translationTask(
            TranslationSession.Configuration(
                source: sourceLanguage?.localeLanguage,
                target: targetLanguage.localeLanguage
            )
        ) { session in
            await model.translate(using: session)
        }
    }

    private var sourceLanguageLabel: String {
        if let sourceLanguage {
            return sourceLanguage.uppercaseDisplayName
        }
        if let detectedSourceLanguage = model.detectedSourceLanguage {
            return "DETECTED: \(detectedSourceLanguage.uppercaseDisplayName)"
        }
        return "DETECTING LANGUAGE…"
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble.fill")
                .foregroundStyle(.yellow)
            Text("ScreenLingo")
                .font(.headline)
            if isLive {
                Text("LIVE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.yellow, in: Capsule())
            }
            Spacer()
            Text(shortcutDisplayName)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private func textBlock(
        label: String,
        text: String,
        color: Color,
        isTarget: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: isTarget ? 17 : 14, weight: isTarget ? .medium : .regular))
                .foregroundStyle(color)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionRow(for text: String) -> some View {
        HStack {
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                model.copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    model.copied = false
                }
            } label: {
                Label(model.copied ? "Copied" : "Copy", systemImage: model.copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
    }

    private func failureView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Translation failed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("The first translation may ask to download the required language models.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class TranslationPanelController {
    private var panel: TranslationPanel?
    private var model: TranslationResultModel?

    func show(
        sourceText: String,
        sourceLanguage: TranslationLanguage?,
        targetLanguage: TranslationLanguage,
        near region: CGRect,
        showsOriginalText: Bool = true,
        isLive: Bool = false,
        shortcutDisplayName: String
    ) {
        close()

        let model = TranslationResultModel(sourceText: sourceText)
        self.model = model

        let panel = TranslationPanel(
            contentRect: CGRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        panel.onCancel = { [weak self] in
            self?.close()
        }

        panel.contentView = NSHostingView(
            rootView: TranslationCardView(
                model: model,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                showsOriginalText: showsOriginalText,
                isLive: isLive,
                shortcutDisplayName: shortcutDisplayName
            ) { [weak self] in
                self?.close()
            }
        )
        panel.setFrameOrigin(origin(for: panel.frame.size, near: region))
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
        model = nil
    }

    private func origin(for panelSize: CGSize, near region: CGRect) -> CGPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(region) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let margin: CGFloat = 12

        var x = region.midX - panelSize.width / 2
        x = min(max(x, visibleFrame.minX + margin), visibleFrame.maxX - panelSize.width - margin)

        let belowY = region.minY - panelSize.height - margin
        let aboveY = region.maxY + margin
        let y: CGFloat
        if belowY >= visibleFrame.minY + margin {
            y = belowY
        } else if aboveY + panelSize.height <= visibleFrame.maxY - margin {
            y = aboveY
        } else {
            y = min(max(region.midY - panelSize.height / 2, visibleFrame.minY + margin), visibleFrame.maxY - panelSize.height - margin)
        }

        return CGPoint(x: x, y: y)
    }
}

final class TranslationPanel: NSPanel {
    var onCancel: (() -> Void)?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        sharingType = .none
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
