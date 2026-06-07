import Foundation
import SwiftUI

private struct CurrentBabyStoreKey: EnvironmentKey {
    static let defaultValue = CurrentBabyEnvironment()
}

public extension EnvironmentValues {
    var currentBaby: CurrentBabyEnvironment {
        get { self[CurrentBabyStoreKey.self] }
        set { self[CurrentBabyStoreKey.self] = newValue }
    }
}

/// Global current-baby selection for Timeline / FamilyFeed filtering.
@MainActor
public final class CurrentBabyEnvironment: ObservableObject {
    @Published public private(set) var currentBabyId: String?
    @Published public private(set) var babies: [BabyProfile] = []

    private let defaultsKey = "com.babycamera.currentBabyId"

    public init(restorePersistedSelection: Bool = true) {
        if restorePersistedSelection {
            currentBabyId = UserDefaults.standard.string(forKey: defaultsKey)
        }
    }

    public var currentBaby: BabyProfile? {
        guard let currentBabyId else { return babies.first }
        return babies.first(where: { $0.id == currentBabyId }) ?? babies.first
    }

    public func replaceBabies(_ babies: [BabyProfile]) {
        self.babies = babies
        if let currentBabyId, babies.contains(where: { $0.id == currentBabyId }) {
            return
        }
        select(babyId: babies.first?.id)
    }

    public func select(babyId: String?) {
        currentBabyId = babyId
        if let babyId {
            UserDefaults.standard.set(babyId, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    public func upsert(_ baby: BabyProfile) {
        if let index = babies.firstIndex(where: { $0.id == baby.id }) {
            babies[index] = baby
        } else {
            babies.append(baby)
        }
        if currentBabyId == nil {
            select(babyId: baby.id)
        }
    }

    public func remove(id: String) {
        babies.removeAll { $0.id == id }
        if currentBabyId == id {
            select(babyId: babies.first?.id)
        }
    }
}
