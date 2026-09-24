import SwiftUI

/// 可选字符串输入行，空字符串写回 nil。
struct TextRow: View {
    let title: LocalizedStringKey
    @Binding var value: String?
    var axis: Axis = .horizontal

    var body: some View {
        if axis == .vertical {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                TextField(title, text: binding, axis: .vertical)
                    .lineLimit(1...5)
            }
        } else {
            LabeledContent(title) {
                TextField(title, text: binding)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var binding: Binding<String> {
        Binding(get: { value ?? "" }, set: { value = $0.isEmpty ? nil : $0 })
    }
}

/// 数字输入行。输入过程中实时写回，避免点“保存”时最后一次输入丢失。
struct NumberRow: View {
    let title: LocalizedStringKey
    @Binding var value: Double?
    var unit: String? = nil
    var prefix: String? = nil
    var maxFractionDigits = 4
    var allowsNegative = false

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                if let prefix { Text(prefix).foregroundStyle(.secondary) }
                TextField("—", text: $text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(allowsNegative ? .numbersAndPunctuation : .decimalPad)
                    .focused($focused)
                    .fixedSize()
                if let unit { Text(unit).foregroundStyle(.secondary) }
            }
        }
        .onAppear { text = Self.format(value, maxFractionDigits) }
        .onChange(of: value) { _, newValue in
            if !focused { text = Self.format(newValue, maxFractionDigits) }
        }
        .onChange(of: text) { _, newText in
            // 文本只是当前值的显示形式时不回写，避免把精确值替换成四舍五入后的值。
            guard newText != Self.format(value, maxFractionDigits) else { return }
            let parsed = Self.parse(newText)
            if parsed != value { value = parsed }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { text = Self.format(value, maxFractionDigits) }
        }
    }

    static func format(_ value: Double?, _ digits: Int) -> String {
        guard let value else { return "" }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = digits
        return f.string(from: NSNumber(value: value)) ?? ""
    }

    static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }
}

struct IntRow: View {
    let title: LocalizedStringKey
    @Binding var value: Int?
    var unit: String? = nil

    var body: some View {
        NumberRow(
            title: title,
            value: Binding(get: { value.map(Double.init) }, set: { value = $0.map { Int($0.rounded()) } }),
            unit: unit,
            maxFractionDigits: 0
        )
    }
}

/// 可选枚举选择器；当前值不在列表中时保留为“其他”。
struct OptionalPicker<Option: Identifiable & Hashable>: View where Option.ID == Int {
    let title: LocalizedStringKey
    @Binding var value: Int?
    let options: [Option]
    let label: (Option) -> String

    var body: some View {
        Picker(title, selection: $value) {
            Text("Not Set").tag(Int?.none)
            ForEach(options) { option in
                Text(label(option)).tag(Int?.some(option.id))
            }
            if let value, !options.contains(where: { $0.id == value }) {
                Text("Other (\(value))").tag(Int?.some(value))
            }
        }
    }
}
