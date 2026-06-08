import Foundation

extension JSONDecoder {
    /// Decoder matching the backend: ISO-8601 dates (with or without fractional
    /// seconds).
    static var cece: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter.ceceFractional.date(from: raw)
                ?? ISO8601DateFormatter.cecePlain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: d.codingPath, debugDescription: "Bad ISO-8601 date: \(raw)")
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    static var cece: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension ISO8601DateFormatter {
    static let ceceFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let cecePlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
