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
        .padding(.horizontal, 16)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                TextField("Enter city", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .focused($fieldFocused)
                    .onSubmit { if let first = model.results.first { model.select(first) } }
                if model.city != nil {
                    Button { model.cancelEditing() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)))

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(model.results) { result in
                        Button { model.select(result) } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
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
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.city?.name ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    if let sub = model.city?.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer()
                Button { model.beginEditing() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
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
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Button("Retry") { Task { await model.refresh(force: true) } }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
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
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                Text(WeatherCode.text(data.code))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Feels like \(temp(data.apparentTemperature))")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
    }

    private func forecast(_ data: WeatherData) -> some View {
        HStack(spacing: 0) {
            ForEach(data.daily.prefix(5)) { day in
                VStack(spacing: 4) {
                    Text(weekday(day.date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Image(systemName: WeatherCode.symbol(day.code, isDay: true))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 15))
                        .frame(height: 20)
                    Text(temp(day.max))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                    Text(temp(day.min))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
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
