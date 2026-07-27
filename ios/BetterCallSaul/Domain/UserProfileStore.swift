import Foundation
import Observation

@MainActor
@Observable
final class UserProfileStore {
    static let nameStorageKey = "betterCallSaul.profile.name"
    static let defaultName = "Алим"

    private(set) var name: String
    private let storage: UserDefaults

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        let savedName = storage.string(forKey: Self.nameStorageKey)
        name = Self.normalized(savedName) ?? Self.defaultName
    }

    @discardableResult
    func updateName(_ value: String) -> Bool {
        guard let normalized = Self.normalized(value) else {
            return false
        }
        name = normalized
        storage.set(normalized, forKey: Self.nameStorageKey)
        return true
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
