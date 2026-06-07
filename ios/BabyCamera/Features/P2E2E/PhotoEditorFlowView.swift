import BabyCameraEditor
import DesignSystem
import SwiftUI

/// 编辑器 Shell：滤镜选择 + 保存（T2.15 EditorRenderer 导出）。
struct PhotoEditorFlowView<Store: PhotoEditorFlowManaging & ObservableObject>: View {
    @ObservedObject var store: Store
    let photoId: String
    let isReEdit: Bool

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            header
            filterPicker
            actionButtons
            Text(store.statusMessage)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
                .accessibilityIdentifier("editorStatusLabel")
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.background)
        .accessibilityIdentifier("photoEditorView")
        .navigationTitle(isReEdit ? "重新编辑" : "编辑照片")
    }

    private var header: some View {
        HStack {
            Text(isReEdit ? "重新编辑模式" : "编辑模式")
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            Text(photoId)
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)
                .accessibilityIdentifier("editorPhotoIdLabel")
        }
    }

    private var filterPicker: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("滤镜")
                .font(DSTypography.bodyEmphasis)

            Picker("滤镜", selection: Binding(
                get: { store.toolbarBinding.filter.filterID },
                set: { id in
                    var binding = store.toolbarBinding
                    binding.filter.selectFilter(id)
                    store.toolbarBinding = binding
                }
            )) {
                ForEach(FilterCatalog.editablePresets) { preset in
                    Text(preset.displayName).tag(preset.id)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityIdentifier("filterPicker")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DSSpacing.sm) {
            Button {
                store.applyCurrentFilter(to: photoId)
            } label: {
                Label("应用滤镜", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DSColors.primary)
            .accessibilityIdentifier("applyFilterButton")

            if isReEdit {
                Button {
                    Task { await store.finishReEditAndReturnToCamera(photoId: photoId) }
                } label: {
                    Label(store.reEditCompleteButtonTitle, systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.primary)
                .disabled(store.isSaving)
                .accessibilityIdentifier("finishReEditButton")
            } else {
                Button {
                    Task { await store.savePhoto(photoId: photoId) }
                } label: {
                    Label("保存到 Timeline", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.primary)
                .disabled(store.isSaving)
                .accessibilityIdentifier("savePhotoButton")
            }
        }
    }
}
