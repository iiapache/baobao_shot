import BabyCameraNetwork
import Foundation

@MainActor
public final class BabyEditViewModel: ObservableObject {
    public enum Mode: Equatable {
        case create
        case edit(BabyProfile)
    }

    @Published public var name = ""
    @Published public var birthDate = Date()
    @Published public var hasBirthTime = false
    @Published public var birthTime = Date()
    @Published public var gender: BabyGender?
    @Published public var isLoading = false
    @Published public var isUploadingAvatar = false
    @Published public var validationMessage: String?
    @Published public var errorMessage: String?
    @Published public private(set) var savedProfile: BabyProfile?
    @Published public private(set) var avatarURL: String?

    public let mode: Mode
    private let service: BabyService
    private let currentBabyStore: CurrentBabyEnvironment

    public init(
        mode: Mode,
        service: BabyService,
        currentBabyStore: CurrentBabyEnvironment
    ) {
        self.mode = mode
        self.service = service
        self.currentBabyStore = currentBabyStore

        if case let .edit(profile) = mode {
            name = profile.name
            if let date = BabyFormValidation.date(from: profile.birthDate) {
                birthDate = date
            }
            if let timeString = profile.birthTime,
               let time = BabyFormValidation.time(from: timeString) {
                hasBirthTime = true
                birthTime = time
            }
            gender = profile.gender
            avatarURL = profile.avatarURL
        }
    }

    public var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    public var canSave: Bool {
        BabyFormValidation.validate(
            name: name,
            birthDate: BabyFormValidation.birthDateString(from: birthDate)
        ) == nil && !isLoading
    }

    public var navigationTitle: String {
        isEditing ? "编辑宝宝" : "添加宝宝"
    }

    public func validateForm() -> Bool {
        let message = BabyFormValidation.validate(
            name: name,
            birthDate: BabyFormValidation.birthDateString(from: birthDate)
        )
        validationMessage = message
        return message == nil
    }

    public func save() async -> BabyProfile? {
        guard validateForm() else { return nil }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let profile = buildProfile()

        do {
            let saved: BabyProfile
            switch mode {
            case .create:
                saved = try await service.createBaby(profile)
            case .edit:
                saved = try await service.updateBaby(profile)
            }
            savedProfile = saved
            avatarURL = saved.avatarURL
            currentBabyStore.upsert(saved)
            currentBabyStore.select(babyId: saved.id)
            return saved
        } catch {
            errorMessage = mapError(error)
            return nil
        }
    }

    public func delete() async -> Bool {
        guard case let .edit(profile) = mode else { return false }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.deleteBaby(id: profile.id)
            currentBabyStore.remove(id: profile.id)
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    public func uploadAvatar(imageData: Data, contentType: String = "image/jpeg") async {
        guard case let .edit(profile) = mode else {
            validationMessage = "请先保存宝宝档案后再上传头像"
            return
        }

        isUploadingAvatar = true
        errorMessage = nil
        defer { isUploadingAvatar = false }

        do {
            let updated = try await service.uploadAvatar(
                babyId: profile.id,
                imageData: imageData,
                contentType: contentType
            )
            avatarURL = updated.avatarURL
            currentBabyStore.upsert(updated)
        } catch {
            errorMessage = mapError(error)
        }
    }

    private func buildProfile() -> BabyProfile {
        let trimmedName = BabyFormValidation.trimmedName(name)
        let birthDateString = BabyFormValidation.birthDateString(from: birthDate)
        let birthTimeString = hasBirthTime ? BabyFormValidation.birthTimeString(from: birthTime) : nil

        switch mode {
        case .create:
            return BabyProfile(
                id: UUID().uuidString,
                familyId: "",
                name: trimmedName,
                gender: gender,
                birthDate: birthDateString,
                birthTime: birthTimeString,
                avatarURL: avatarURL
            )
        case let .edit(existing):
            return BabyProfile(
                id: existing.id,
                familyId: existing.familyId,
                name: trimmedName,
                gender: gender,
                birthDate: birthDateString,
                birthTime: birthTimeString,
                avatarURL: avatarURL ?? existing.avatarURL,
                updatedAt: existing.updatedAt
            )
        }
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return "操作失败，请稍后重试"
    }
}
