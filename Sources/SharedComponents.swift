import SwiftUI

// MARK: - PanelCard

struct PanelCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - StatusPill

struct StatusPill: View {
    let title: String
    let value: String
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.tail)
                .foregroundStyle(highlighted ? .orange : .primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(highlighted ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - StatusTile

struct StatusTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

// MARK: - StatusRow

struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title + ":")
                .fontWeight(.semibold)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - ActionTone

enum ActionTone {
    case primary
    case neutral
    case destructive

    func background(disabled: Bool) -> Color {
        if disabled {
            return Color.secondary.opacity(0.08)
        }
        switch self {
        case .primary:
            return Color.accentColor.opacity(0.18)
        case .neutral:
            return Color.secondary.opacity(0.1)
        case .destructive:
            return Color.red.opacity(0.12)
        }
    }

    func border(disabled: Bool) -> Color {
        if disabled {
            return Color.secondary.opacity(0.12)
        }
        switch self {
        case .primary:
            return Color.accentColor.opacity(0.35)
        case .neutral:
            return Color.secondary.opacity(0.2)
        case .destructive:
            return Color.red.opacity(0.35)
        }
    }

    func foreground(disabled: Bool) -> Color {
        disabled ? .secondary : .primary
    }
}

// MARK: - ActionTileStyle

struct ActionTileStyle: ButtonStyle {
    let tone: ActionTone
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !isDisabled
        configuration.label
            .foregroundStyle(tone.foreground(disabled: isDisabled))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tone.background(disabled: isDisabled))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tone.border(disabled: isDisabled), lineWidth: pressed ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(pressed ? 0.97 : 1.0)
            .brightness(pressed ? -0.06 : 0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - ResponsiveBorderedStyle

struct ResponsiveBorderedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        configuration.isPressed ? Color.primary.opacity(0.3) : Color.primary.opacity(0.12),
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - ResponsiveBorderedProminentStyle

struct ResponsiveBorderedProminentStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.75) : Color.accentColor)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - PressScaleStyle

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - ActionTileButton

struct ActionTileButton: View {
    let title: String
    let icon: String
    let tone: ActionTone
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ActionTileStyle(tone: tone, isDisabled: isDisabled))
        .disabled(isDisabled)
    }
}

// MARK: - ManualSectionCard

struct ManualSectionCard: View {
    let title: String
    let summary: String
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .fontWeight(.semibold)
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
