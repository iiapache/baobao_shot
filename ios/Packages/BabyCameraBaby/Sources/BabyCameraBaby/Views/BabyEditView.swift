import BabyCameraNetwork
import DesignSystem
import PhotosUI
import SwiftUI

public struct BabyEditView: View {
    @ObservedObject private var viewModel: BabyEditViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    private let onSaved: (BabyProfile) -> Void
    private let onDeleted: () -> Void

    public init(
        viewModel: BabyEditViewModel,
        onSaved: @escaping (BabyProfile) -> Void = { _ in },
        onDeleted: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    public var body: some View {
        Form {
            avatarSection
            requiredSection
            optionalSection

            if viewModel.isEditing {
                deleteSection
            }

            if let validationMessage = viewModel.validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(DSColors.error)
                        .font(DSTypography.footnote)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(DSColors.error)
                        .font(DSTypography.footnote)
                }
            }
        }
        .navigationTitle(viewModel.navigationTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task {
                        if let profile = await viewModel.save() {
                            onSaved(profile)
                        }
                    }
                }
                .disabled(!viewModel.canSave || viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                DSLoadingView(message: "保存中…")
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task { await handlePhotoSelection(newItem) }
        }
    }

    private var avatarSection: some View {
        Section("头像") {
            HStack(spacing: DSSpacing.md) {
                BabyAvatarView(
                    name: viewModel.name.isEmpty ? "宝" : viewModel.name,
                    avatarURL: viewModel.avatarURL,
                    size: 72
                )

                if viewModel.isEditing {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            viewModel.isUploadingAvatar ? "上传中…" : "更换头像",
                            systemImage: "photo"
                        )
                    }
                    .disabled(viewModel.isUploadingAvatar)
                } else {
                    Text("保存档案后可上传头像")
                        .font(DSTypography.footnote)
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
        }
    }

    private var requiredSection: some View {
        Section("必填信息") {
            TextField("宝宝小名", text: $viewModel.name)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("babyNameField")

            DatePicker(
                "出生日期",
                selection: $viewModel.birthDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .accessibilityIdentifier("babyBirthDatePicker")
        }
    }

    private var optionalSection: some View {
        Section("选填信息") {
            Picker("性别", selection: $viewModel.gender) {
                Text("暂不填写").tag(BabyGender?.none)
                ForEach(BabyGender.allCases.filter { $0 != .unknown }) { gender in
                    Text(gender.displayName).tag(Optional(gender))
                }
            }

            Toggle("填写出生时间", isOn: $viewModel.hasBirthTime)

            if viewModel.hasBirthTime {
                DatePicker(
                    "出生时间",
                    selection: $viewModel.birthTime,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityIdentifier("babyBirthTimePicker")
            }
        }
    }

    private var deleteSection: some View {
        Section {
            DSButton("删除宝宝档案", style: .destructive, isLoading: viewModel.isLoading) {
                Task {
                    if await viewModel.delete() {
                        onDeleted()
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self) else {
            return
        }
        await viewModel.uploadAvatar(imageData: data)
    }
}

#Preview {
    NavigationStack {
        BabyEditView(
            viewModel: BabyEditViewModel(
                mode: .create,
                service: BabyService(
                    familyId: "fam_preview",
                    client: makeAnonymousClient()
                ),
                currentBabyStore: CurrentBabyEnvironment(restorePersistedSelection: false)
            )
        )
    }
}
