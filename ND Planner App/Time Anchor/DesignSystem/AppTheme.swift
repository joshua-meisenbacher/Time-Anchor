import SwiftUI
import UIKit

private struct VisualSupportModeKey: EnvironmentKey {
    static let defaultValue: VisualSupportMode = .standard
}

extension EnvironmentValues {
    var visualSupportMode: VisualSupportMode {
        get { self[VisualSupportModeKey.self] }
        set { self[VisualSupportModeKey.self] = newValue }
    }
}

enum AppTheme {
    enum Colors {
        static let canvas = dynamic(
            light: UIColor(red: 0.96, green: 0.97, blue: 0.96, alpha: 1),
            dark: UIColor(red: 0.06, green: 0.09, blue: 0.08, alpha: 1)
        )
        static let card = dynamic(
            light: .white,
            dark: UIColor(red: 0.11, green: 0.14, blue: 0.13, alpha: 1)
        )
        static let controlBackground = dynamic(
            light: UIColor(red: 0.88, green: 0.92, blue: 0.90, alpha: 1),
            dark: UIColor(red: 0.17, green: 0.22, blue: 0.20, alpha: 1)
        )
        static let primary = dynamic(
            light: UIColor(red: 0.18, green: 0.45, blue: 0.39, alpha: 1),
            dark: UIColor(red: 0.46, green: 0.79, blue: 0.69, alpha: 1)
        )
        static let primaryMuted = dynamic(
            light: UIColor(red: 0.82, green: 0.90, blue: 0.86, alpha: 1),
            dark: UIColor(red: 0.23, green: 0.33, blue: 0.29, alpha: 1)
        )
        static let text = dynamic(
            light: UIColor(red: 0.09, green: 0.12, blue: 0.12, alpha: 1),
            dark: UIColor(red: 0.93, green: 0.95, blue: 0.94, alpha: 1)
        )
        static let secondaryText = dynamic(
            light: UIColor(red: 0.25, green: 0.31, blue: 0.30, alpha: 1),
            dark: UIColor(red: 0.76, green: 0.81, blue: 0.79, alpha: 1)
        )
        static let border = dynamic(
            light: UIColor(red: 0.78, green: 0.83, blue: 0.81, alpha: 1),
            dark: UIColor(red: 0.28, green: 0.34, blue: 0.32, alpha: 1)
        )

        private static func dynamic(light: UIColor, dark: UIColor) -> Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            })
        }
    }

    enum Typography {
        static let heroTitle = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let cardTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let supporting = Font.system(size: 15, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.visualSupportMode) private var visualSupportMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFillColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: visualSupportMode == .lowerStimulation ? 0.8 : 1)
        )
        .shadow(color: Color.black.opacity(visualSupportMode == .lowerStimulation ? 0.015 : 0.04), radius: visualSupportMode == .lowerStimulation ? 6 : 12, x: 0, y: visualSupportMode == .lowerStimulation ? 2 : 6)
    }

    private var cardFillColor: Color {
        visualSupportMode == .lowerStimulation
            ? AppTheme.Colors.canvas.opacity(0.98)
            : AppTheme.Colors.card
    }

    private var borderColor: Color {
        visualSupportMode == .lowerStimulation
            ? AppTheme.Colors.border.opacity(0.9)
            : AppTheme.Colors.border.opacity(0.7)
    }
}

struct CueBanner: View {
    let text: String
    @Environment(\.visualSupportMode) private var visualSupportMode

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if visualSupportMode == .standard {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(AppTheme.Colors.primary)
            } else {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            Text(text)
                .font(AppTheme.Typography.supporting)
                .foregroundStyle(AppTheme.Colors.text)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bannerBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(bannerBorder, lineWidth: visualSupportMode == .lowerStimulation ? 0.8 : 0)
        )
    }

    private var bannerBackground: Color {
        visualSupportMode == .lowerStimulation
            ? AppTheme.Colors.card
            : AppTheme.Colors.controlBackground
    }

    private var bannerBorder: Color {
        AppTheme.Colors.border.opacity(0.9)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.visualSupportMode) private var visualSupportMode

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.cardTitle)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(primaryFill(configuration.isPressed))
            )
    }

    private func primaryFill(_ isPressed: Bool) -> Color {
        if visualSupportMode == .lowerStimulation {
            return AppTheme.Colors.primary.opacity(isPressed ? 0.86 : 0.94)
        }
        return AppTheme.Colors.primary.opacity(isPressed ? 0.88 : 1)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.visualSupportMode) private var visualSupportMode

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.cardTitle)
            .foregroundStyle(AppTheme.Colors.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(secondaryFill(configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.Colors.border.opacity(0.95), lineWidth: 1)
            )
    }

    private func secondaryFill(_ isPressed: Bool) -> Color {
        if visualSupportMode == .lowerStimulation {
            return AppTheme.Colors.card.opacity(isPressed ? 0.9 : 1)
        }
        return AppTheme.Colors.controlBackground.opacity(isPressed ? 0.92 : 1)
    }
}

struct ScreenModeBadge: View {
    let title: String

    @Environment(\.visualSupportMode) private var visualSupportMode

    var body: some View {
        Text(title.uppercased())
            .font(AppTheme.Typography.caption.weight(.semibold))
            .kerning(0.6)
            .foregroundStyle(visualSupportMode == .lowerStimulation ? AppTheme.Colors.text : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(visualSupportMode == .lowerStimulation
                          ? AppTheme.Colors.card
                          : AppTheme.Colors.primary)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppTheme.Colors.border.opacity(visualSupportMode == .lowerStimulation ? 0.95 : 0), lineWidth: 1)
            )
    }
}
