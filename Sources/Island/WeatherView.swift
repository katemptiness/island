import SwiftUI

/// Weather tab: either the city-search editor or the current weather + forecast.
/// While editing, it pins the island open (so it won't collapse as you move the
/// mouse to type) and focuses the text field.
struct WeatherView: View {
    @ObservedObject var model: WeatherModel
    @Binding var isPinned: Bool
    @FocusState private var fieldFocused: Bool

    private var editing: Bool { model.isEditing || model.city == nil }

    var body: some View {
        Group {
            if editing {
                searchUI
            } else {
                weatherUI
            }
        }
        .onAppear {
            isPinned = editing
            fieldFocused = editing
            Task { await model.refresh() }
        }
        .onDisappear { isPinned = false }
        .onChange(of: model.isEditing) { _, _ in
            isPinned = editing
            fieldFocused = editing
        }
    }

    // MARK: - Search

    private var searchUI: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
            HStack(spacing: Theme.Spacing.tight) {
                Image(systemName: "magnifyingglass")
                    .font(Theme.Font.subhead)
                    .foregroundStyle(Theme.Text.tertiary)
                TextField("Enter city", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Text.primary)
                    .focused($fieldFocused)
                    .onSubmit { if let first = model.results.first { model.select(first) } }
                if model.city != nil {
                    Button { model.cancelEditing() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Text.faint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.tight)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Fill.subtle))

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(model.results) { result in
                        Button { model.select(result) } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.name)
                                    .font(Theme.Font.subheadEmphasized)
                                    .foregroundStyle(Theme.Text.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Text.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .padding(.horizontal, Theme.Spacing.tight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 170)
        }
        .onChange(of: model.query) { _, _ in model.searchCities() }
    }

    // MARK: - Weather

    private var weatherUI: some View {
        VStack(spacing: Theme.Spacing.section) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.city?.name ?? "")
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Text.primary)
                    if let sub = model.city?.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(Theme.Font.micro)
                            .foregroundStyle(Theme.Text.faint)
                    }
                }
                Spacer()
                Button { model.beginEditing() } label: {
                    Image(systemName: "pencil")
                        .font(Theme.Font.footnote)
                        .foregroundStyle(Theme.Text.tertiary)
                }
                .buttonStyle(.plain)
            }

            phaseContent
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 90)
        case .failed(let message):
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.warn)
                Text(message)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Text.secondary)
                Button("Retry") { Task { await model.refresh(force: true) } }
                    .buttonStyle(.plain)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
        case .loaded(let data):
            current(data)
            forecast(data)
        case .needsCity:
            EmptyView()
        }
    }

    private func current(_ data: WeatherData) -> some View {
        HStack(spacing: 16) {
            Image(systemName: WeatherCode.symbol(data.code, isDay: data.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 38))
            VStack(alignment: .leading, spacing: 2) {
                Text(temp(data.temperature))
                    .font(Theme.Font.display)
                    .foregroundStyle(Theme.Text.primary)
                Text(WeatherCode.text(data.code))
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Text.secondary)
                Text("Feels like \(temp(data.apparentTemperature))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Text.tertiary)
            }
            Spacer()
        }
    }

    private func forecast(_ data: WeatherData) -> some View {
        HStack(spacing: 0) {
            ForEach(data.daily.prefix(5)) { day in
                VStack(spacing: Theme.Spacing.element) {
                    Text(weekday(day.date))
                        .font(Theme.Font.micro)
                        .foregroundStyle(Theme.Text.secondary)
                    Image(systemName: WeatherCode.symbol(day.code, isDay: true))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 15))
                        .frame(height: 20)
                    Text(temp(day.max))
                        .font(Theme.Font.captionEmphasized)
                        .foregroundStyle(Theme.Text.primary)
                    Text(temp(day.min))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Text.faint)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private func temp(_ value: Double) -> String { "\(Int(value.rounded()))°" }

    private func weekday(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
