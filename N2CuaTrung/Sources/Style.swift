import SwiftUI

enum Palette {
    static let navy = Color(red: 0.09, green: 0.15, blue: 0.28)
    static let blue = Color(red: 0.21, green: 0.36, blue: 0.73)
    static let pale = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let teal = Color(red: 0.03, green: 0.58, blue: 0.53)
    static let orange = Color(red: 0.97, green: 0.54, blue: 0.24)
}

/// The *same* generated PNG is used in AppIcon, this brand mark and the
/// widget. Do not substitute unrelated SF Symbols in branded surfaces.
struct BrandMark: View {
    var size: CGFloat = 62
    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            .accessibilityLabel("Logo N2 của Trung")
    }
}

/// Single visual language for all four publisher-oriented learning series.
struct SeriesBookMark: View {
    var active: Bool = false

    var body: some View {
        Image(systemName: "books.vertical.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(active ? .white : Palette.blue)
            .frame(width: 46, height: 46)
            .background(active ? Palette.teal : Palette.blue.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }
}

struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(color.opacity(0.10), in: Capsule())
    }
}

struct LessonPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.navy.opacity(0.055)))
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.weight(.bold)).foregroundColor(Palette.navy)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundColor(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MainButton: View {
    let title: String
    let symbol: String
    var color: Color = Palette.blue
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.83)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 10)
                .foregroundColor(.white)
                .background(color, in: RoundedRectangle(cornerRadius: 13))
                .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}

struct StatBox: View {
    let number: String
    let label: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundColor(Palette.blue)
            Text(number)
                .font(.title2.weight(.bold))
                .foregroundColor(Palette.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
    }
}