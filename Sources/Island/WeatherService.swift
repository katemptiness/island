import Foundation

// MARK: - Domain types

/// A city the user picked, persisted between launches.
struct SavedCity: Codable {
    let name: String
    let country: String?
    let admin1: String?
    let latitude: Double
    let longitude: Double

    var subtitle: String {
        [admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

/// A geocoding search hit from Open-Meteo.
struct GeoResult: Decodable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?

    var subtitle: String {
        [admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

struct DailyForecast: Identifiable {
    var id: TimeInterval { date.timeIntervalSince1970 }
    let date: Date
    let code: Int
    let max: Double
    let min: Double
}

struct WeatherData {
    let temperature: Double
    let apparentTemperature: Double
    let code: Int
    let isDay: Bool
    let daily: [DailyForecast]
}

enum WeatherPhase {
    case needsCity
    case loading
    case loaded(WeatherData)
    case failed(String)
}

// MARK: - WMO weather code → icon / text

enum WeatherCode {
    static func symbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func text(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm, hail"
        default: return "—"
        }
    }
}

// MARK: - Open-Meteo client (free, no API key)

struct WeatherService {
    enum ServiceError: Error { case badURL }

    func geocode(_ name: String) async throws -> [GeoResult] {
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        comps?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps?.url else { throw ServiceError.badURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(GeoResponse.self, from: data)
        return decoded.results ?? []
    }

    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        comps?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "5")
        ]
        guard let url = comps?.url else { throw ServiceError.badURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ForecastResponse.self, from: data).toWeatherData()
    }
}

// MARK: - Wire types

private struct GeoResponse: Decodable {
    let results: [GeoResult]?
}

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature: Double
        let apparentTemperature: Double
        let weatherCode: Int
        let isDay: Int

        // Explicit keys: `convertFromSnakeCase` mangles `temperature_2m` into
        // `temperature2M` (it capitalizes the letter after the digit), so we map
        // the exact JSON names ourselves.
        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let weatherCode: [Int]
        let tempMax: [Double]
        let tempMin: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case tempMax = "temperature_2m_max"
            case tempMin = "temperature_2m_min"
        }
    }

    let current: Current
    let daily: Daily

    func toWeatherData() -> WeatherData {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let count = min(daily.time.count, daily.weatherCode.count,
                        daily.tempMax.count, daily.tempMin.count)
        var days: [DailyForecast] = []
        for i in 0..<count {
            let date = formatter.date(from: daily.time[i]) ?? Date()
            days.append(DailyForecast(date: date, code: daily.weatherCode[i],
                                      max: daily.tempMax[i], min: daily.tempMin[i]))
        }

        return WeatherData(
            temperature: current.temperature,
            apparentTemperature: current.apparentTemperature,
            code: current.weatherCode,
            isDay: current.isDay == 1,
            daily: days
        )
    }
}
