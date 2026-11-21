//
//  SettingsCardComponents.swift
//  Salt
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import SwiftUI

/// Shared header banner card used across Salt App Information views.
struct SettingsHeaderCard: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    var badgeText: String? = nil
    var badgeColor: Color = .blue

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(symbolColor.opacity(0.14))
                    .frame(width: 52, height: 52)

                Image(systemName: symbol)
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(symbolColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let badgeText {
                    Text(badgeText)
                        .font(.caption2.bold())
                        .foregroundStyle(badgeColor)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Shared question-and-answer card used in Support Center.
struct SettingsFAQCard: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appPrimary)

            Text(answer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Shared detail section card used in Privacy Policy and Terms of Service.
struct SettingsDetailCard: View {
    let icon: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.appPrimary)

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appPrimary)
            }

            Text(content)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Shared credit and open-source attribution card used in Acknowledgements.
struct SettingsAttributionCard: View {
    let title: String
    let subtitle: String
    let badge: String
    let badgeColor: Color
    let description: String
    let attributionNote: String
    var linkLabel: String = "Learn More"
    let linkURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(badgeColor)
            }

            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(.quaternary)

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(attributionNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let url = URL(string: linkURL) {
                    Link(destination: url) {
                        HStack(spacing: 2) {
                            Text(linkLabel)
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Full-width capsule button style matching Orchard's primary CTA styling.
struct PrimaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(red: 0xF6 / 255.0, green: 0xF4 / 255.0, blue: 0xF3 / 255.0, alpha: 1.0))
            : Color(uiColor: UIColor(red: 0x29 / 255.0, green: 0x0B / 255.0, blue: 0x00 / 255.0, alpha: 1.0))
    }

    private var foregroundColor: Color {
        colorScheme == .dark
            ? Color(uiColor: UIColor(red: 0x29 / 255.0, green: 0x0B / 255.0, blue: 0x00 / 255.0, alpha: 1.0))
            : .white
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.snappy(duration: 0.15, extraBounce: 0.1), value: configuration.isPressed)
    }
}
