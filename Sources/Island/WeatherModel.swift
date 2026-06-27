import SwiftUI

/// State for the weather feature: the chosen city (persisted), the current
/// weather, and the city-search editing flow. Network results are published on
/// the main thread so SwiftUI stays happy.
final class WeatherModel: ObservableObject {
    @Published var city: SavedCity?
    @Published var phase: WeatherPhase = .needsCity
    @Published var isEditing = false
    @Published var query = ""
    @Published var results: [GeoResult] = []
    /// True while a fetch is in flight; drives the manual-refresh spinner.
    @Published var isRefreshing = false

    /// Background tint derived from the current conditions (nil until loaded).
    var tint: Color? {
        if case .loaded(let data) = phase {
            return IslandTint.weather(code: data.code, isDay: data.isDay)
        }
        return nil
    }

    private let service = WeatherService()
    private let cityKey = "island.weather.city"
    private var lastFetch: Date?
    private var searchTask: Task<Void, Never>?

    init() {
        if let saved = Self.loadCity(key: cityKey) {
            city = saved
            phase = .loading
        } else {
            phase = .needsCity
            isEditing = true
        }
    }

    // MARK: - Weather

    func refresh(force: Bool = false) async {
        guard let city else { return }
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < 600,
           case .loaded = phase {
            return // still fresh
        }
        // Keep existing data visible while refreshing; only show the full-block
        // spinner when there's nothing to display yet.
        let hadData = await MainActor.run { () -> Bool in
            let loaded: Bool
            if case .loaded = self.phase { loaded = true } else { loaded = false }
            self.isRefreshing = true
            if !loaded { self.phase = .loading }
            return loaded
        }
        do {
            let data = try await service.fetchWeather(latitude: city.latitude, longitude: city.longitude)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) { self.phase = .loaded(data) }
                self.lastFetch = Date()
                self.isRefreshing = false
            }
        } catch {
            await MainActor.run {
                // Don't discard good data on a failed refresh; only surface the
                // error when we have nothing else to show.
                if !hadData { self.phase = .failed("Couldn't load weather") }
                self.isRefreshing = false
            }
        }
    }

    // MARK: - City search

    func searchCities() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        guard q.count >= 2 else {
            results = []
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000) // debounce
            guard let self, !Task.isCancelled else { return }
            do {
                let found = try await self.service.geocode(q)
                if Task.isCancelled { return }
                await MainActor.run { self.results = found }
            } catch {
                // keep previous results on a transient failure
            }
        }
    }

    func select(_ result: GeoResult) {
        let saved = SavedCity(name: result.name, country: result.country, admin1: result.admin1,
                              latitude: result.latitude, longitude: result.longitude)
        city = saved
        Self.saveCity(saved, key: cityKey)
        isEditing = false
        query = ""
        results = []
        Task { await refresh(force: true) }
    }

    func beginEditing() {
        query = ""
        results = []
        isEditing = true
    }

    func cancelEditing() {
        guard city != nil else { return } // can't cancel if no city is set yet
        isEditing = false
        query = ""
        results = []
    }

    // MARK: - Persistence

    private static func loadCity(key: String) -> SavedCity? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedCity.self, from: data)
    }

    private static func saveCity(_ city: SavedCity, key: String) {
        if let data = try? JSONEncoder().encode(city) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
