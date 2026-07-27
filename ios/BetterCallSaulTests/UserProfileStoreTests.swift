import XCTest
@testable import BetterCallSaul

@MainActor
final class UserProfileStoreTests: XCTestCase {
    func testFreshProfileUsesDefaultName() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = UserProfileStore(storage: defaults)

        XCTAssertEqual(profile.name, "Алим")
    }

    func testUpdatingNameTrimsAndPersistsForNextStore() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = UserProfileStore(storage: defaults)

        XCTAssertTrue(profile.updateName("  Диана Садыкова \n"))

        let reloaded = UserProfileStore(storage: defaults)
        XCTAssertEqual(profile.name, "Диана Садыкова")
        XCTAssertEqual(reloaded.name, "Диана Садыкова")
    }

    func testBlankNameIsRejectedWithoutReplacingSavedName() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = UserProfileStore(storage: defaults)
        XCTAssertTrue(profile.updateName("Алекс"))

        XCTAssertFalse(profile.updateName(" \n\t "))

        XCTAssertEqual(profile.name, "Алекс")
        XCTAssertEqual(defaults.string(forKey: UserProfileStore.nameStorageKey), "Алекс")
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "UserProfileStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
