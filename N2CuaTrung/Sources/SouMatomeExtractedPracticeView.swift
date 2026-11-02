import SwiftUI

/// Personal source-derived preview. These rows have NOT been reviewed and are
/// intentionally separate from approved flashcards and scored JLPT questions.
/// They stay on the device; never publish commercial textbook excerpts in Git.
struct SouMatomeExtractedPracticeView: View {
    let entries: [SouMatomeSourceEntry]
    @State private var skill = "Tất cả"
    @State private var position = 0
    @State private var revealed = false
    private let skills = ["Tất cả", "Từ vựng", "Kanji", "Ngữ pháp"]

    private var filtered: [SouMatomeSourceEntry] {
        skill == "Tất cả" ? entries : entries.filter { $0.skill == skill }
    }
    private var current: SouMatomeSourceEntry? {
        filtered.indices.contains(position) ? filtered[position] : nil
    }

    /// Show each Kanji's unambiguous reference sound. A missing sound remains
    /// visible as a dash, rather than silently disappearing or being invented.
    private func hanViet(for entry: SouMatomeSourceEntry) -> String? {
        if entry.skill == "Kanji",
           let source = entry.sourceHanViet?.trimmingCharacters(in: .whitespacesAndNewlines),
           !source.isEmpty { return source.lowercased() }
        var parts: [String] = []
        for scalar in entry.heading.unicodeScalars {
            guard (0x3400...0x9FFF).contains(scalar.value)
               || (0xF900...0xFAFF).contains(scalar.value) else { continue }
            let kanji = String(scalar)
            let sound = KangxiReference.info(for: kanji)?.sinoVietnamese
            if let sound, !sound.isEmpty,
               !sound.contains(","), !sound.contains("、"), !sound.contains("/") {
                parts.append(sound.lowercased())
            } else {
                parts.append("—")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func change(_ amount: Int) {
        guard !filtered.isEmpty else { return }
        JapaneseVoice.shared.stop()
        position = (position + amount + filtered.count) % filtered.count
        revealed = false
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 590
            let gap: CGFloat = compact ? 5 : 8
            let cardHeight = max(120, geometry.size.height - 174 - gap * 4)
            VStack(spacing: gap) {
                Picker("Kỹ năng", selection: $skill) {
                    ForEach(skills, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: skill) { _ in position = 0; revealed = false }

                HStack {
                    Text(filtered.isEmpty ? "0 / 0" : "\(position + 1) / \(filtered.count)")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("Kho trích xuất · chưa hiệu đính")
                        .font(.caption2)
                        .foregroundColor(Palette.orange)
                }.frame(height: 24)

                if let entry = current {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18).fill(.white)
                        VStack(spacing: compact ? 7 : 11) {
                            Spacer(minLength: 0)
                            Text(entry.heading)
                                .font(.system(size: compact ? 35 : 44, weight: .bold))
                                .foregroundColor(Palette.navy)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.55)
                            if revealed {
                                if let han = hanViet(for: entry) {
                                    Text(han)
                                        .font(.system(size: compact ? 16 : 19, weight: .semibold))
                                        .foregroundColor(Palette.orange)
                                        .multilineTextAlignment(.center)
                                }
                                if let kana = entry.reading, !kana.isEmpty {
                                    Text(kana).font(.system(size: compact ? 15 : 18))
                                        .foregroundColor(Palette.blue)
                                        .multilineTextAlignment(.center)
                                }
                                Text(entry.detail.isEmpty ? "Chưa trích được nghĩa tiếng Việt" : entry.detail)
                                    .font(.system(size: compact ? 17 : 21, weight: .medium))
                                    .foregroundColor(entry.detail.isEmpty ? Palette.orange : Palette.teal)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(4)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer(minLength: 0)
                            Text("Trang \(entry.page) · \(entry.skill) · chạm để lật")
                                .font(.caption2).foregroundColor(.secondary)
                        }.padding(compact ? 9 : 14)
                    }
                    .frame(height: cardHeight)
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.teal.opacity(0.2)))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                    .gesture(DragGesture(minimumDistance: 0).onEnded { drag in
                        let dx = drag.translation.width, dy = drag.translation.height
                        if max(abs(dx), abs(dy)) < 15 { revealed.toggle() }
                        else if abs(dx) >= abs(dy), abs(dx) > 40 {
                            change(dx < 0 ? 1 : -1)
                        } else if abs(dy) > 40 { change(dy < 0 ? 1 : -1) }
                    })
                    HStack(spacing: 8) {
                        button("Nghe từ", color: Palette.blue) {
                            JapaneseVoice.shared.speak(entry.reading?.isEmpty == false
                                                       ? entry.reading! : entry.heading)
                        }
                        button("Từ tiếp theo", color: Palette.teal) { change(1) }
                    }
                    HStack(spacing: 8) {
                        button("Từ trước", color: Palette.navy) { change(-1) }
                        button(revealed ? "Mặt trước" : "Xem mặt sau", color: Palette.orange) {
                            revealed.toggle()
                        }
                    }
                } else {
                    Text("Chưa có mục trích xuất cho kỹ năng này.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Palette.pale)
        .navigationTitle("Thẻ từ dữ liệu trích xuất")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { JapaneseVoice.shared.stop() }
    }

    private func button(_ label: String, color: Color,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.subheadline.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(color, in: RoundedRectangle(cornerRadius: 10))
                .foregroundColor(.white)
        }.buttonStyle(.plain)
    }
}
