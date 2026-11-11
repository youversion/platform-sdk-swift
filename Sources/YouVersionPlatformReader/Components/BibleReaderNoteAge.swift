import SwiftUI

struct BibleReaderNoteAge: View {
    @Environment(\.locale) private var locale
    let createdTime: String

    var body: some View {
        if let date = Self.date(from: createdTime) {
            TimelineView(.periodic(from: date, by: 60)) { context in
                Text(Self.ageText(since: date, now: context.date, locale: locale))
                    .accessibilityLabel(Text(date, format: .relative(presentation: .numeric, unitsStyle: .wide).locale(locale)))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    /// Parses API timestamps with or without fractional seconds and an explicit time zone.
    static func date(from value: String) -> Date? {
        (try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))) ??
            (try? Date(value, strategy: .iso8601))
    }

    /// Formats completed days, hours, or minutes using the view's locale.
    static func ageText(since date: Date, now: Date, locale: Locale) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        guard elapsed >= 60 else {
            return nowText(locale: locale)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 1
        return formatter.string(from: elapsed) ?? nowText(locale: locale)
    }

    private static func nowText(locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .beginningOfSentence
        return formatter.localizedString(from: DateComponents(second: 0))
    }

}
