import BabyCameraBaby
import DesignSystem
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 家庭圈发布编辑器（T5.10）：≤9 图 + 1 视频 + 文案 + 可见范围 + 水印预览。
public struct PostComposerView: View {
    @ObservedObject private var viewModel: PostComposerViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedVideoItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: PostComposerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                captionSection
                mediaSection
                PostWatermarkPreviewCard(
                    previewImage: viewModel.watermarkPreviewImage,
                    isLoading: viewModel.isRefreshingWatermarkPreview
                )
                PostVisibilityPicker(visibility: $viewModel.visibility)

                if let notice = viewModel.captionNotice {
                    Text(notice)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.warning)
                }

                if let message = viewModel.validationMessage {
                    Text(message)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.error)
                }

                if case let .failed(message) = viewModel.phase {
                    Text(message)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSColors.error)
                }
            }
            .padding(DSSpacing.md)
        }
        .navigationTitle("发布动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: DSSpacing.xs) {
                    Button("智能文案") {
                        Task { await viewModel.generateSmartCaptions() }
                    }
                    .disabled(!viewModel.canGenerateSmartCaptions || viewModel.isGeneratingCaptions)
                    .accessibilityLabel("生成智能文案")

                    Button("模板") {
                        viewModel.applyDefaultCaption()
                    }
                    .accessibilityLabel("应用默认文案模板")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("发布") {
                    Task { await publishAndDismissIfNeeded() }
                }
                .disabled(!viewModel.canPublish || viewModel.isPublishing)
            }
        }
        .safeAreaInset(edge: .bottom) {
            DSButton(
                "发布到家庭圈",
                style: .primary,
                isLoading: viewModel.isPublishing,
                isDisabled: !viewModel.canPublish
            ) {
                Task { await publishAndDismissIfNeeded() }
            }
            .padding(DSSpacing.md)
        }
        .onChange(of: viewModel.caption) { _ in
            viewModel.refreshValidation()
        }
        .onChange(of: selectedPhotoItems) { items in
            Task { await importPhotos(from: items) }
        }
        .onChange(of: selectedVideoItem) { item in
            Task { await importVideo(from: item) }
        }
        .sheet(isPresented: $viewModel.showCaptionPicker) {
            if case let .ready(candidates, remainingToday) = viewModel.captionPickerPhase {
                CaptionPickerView(
                    candidates: candidates,
                    remainingToday: remainingToday,
                    limitMessage: nil,
                    onSelect: { viewModel.selectCaptionCandidate($0) },
                    onDismiss: { viewModel.dismissCaptionPicker() }
                )
            }
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text("文案")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Text(PostCaptionTemplate.templatePattern)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textTertiary)
            }

            HStack(alignment: .top, spacing: DSSpacing.xs) {
                TextField("写点什么…", text: $viewModel.caption, axis: .vertical)
                    .lineLimit(3...8)
                    .font(DSTypography.body)
                    .accessibilityLabel("发布文案")

                if viewModel.isGeneratingCaptions {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, DSSpacing.xxs)
                }
            }
            .padding(DSSpacing.sm)
            .background(DSColors.surfaceGrouped)
            .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            PostMediaGridView(
                items: viewModel.mediaItems,
                onRemove: { viewModel.removeMedia(id: $0) }
            )

            HStack(spacing: DSSpacing.sm) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: viewModel.remainingImageSlots,
                    matching: .images
                ) {
                    pickerLabel(
                        title: "选图片",
                        systemImage: "photo.on.rectangle.angled",
                        enabled: viewModel.canAddImage
                    )
                }
                .disabled(!viewModel.canAddImage)

                PhotosPicker(
                    selection: $selectedVideoItem,
                    matching: .videos
                ) {
                    pickerLabel(
                        title: "选视频",
                        systemImage: "video.fill",
                        enabled: viewModel.canAddVideo
                    )
                }
                .disabled(!viewModel.canAddVideo)
            }
        }
    }

    private func pickerLabel(title: String, systemImage: String, enabled: Bool) -> some View {
        HStack(spacing: DSSpacing.xxs) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(DSTypography.buttonSmall)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.sm)
        .foregroundStyle(enabled ? DSColors.primary : DSColors.textTertiary)
        .background(DSColors.primaryMuted)
        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        .opacity(enabled ? 1 : 0.5)
    }

    private func publishAndDismissIfNeeded() async {
        await viewModel.publish()
        if case .published = viewModel.phase {
            dismiss()
        }
    }

    private func importPhotos(from items: [PhotosPickerItem]) async {
        defer { selectedPhotoItems = [] }

        for item in items {
            guard viewModel.canAddImage else { break }
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let dimensions = imageDimensions(from: data)
            let media = PostComposerMediaItem(
                kind: .image,
                previewData: data,
                width: dimensions.width,
                height: dimensions.height,
                deepSynth: false
            )
            _ = viewModel.addImage(media)
        }
    }

    private func importVideo(from item: PhotosPickerItem?) async {
        defer { selectedVideoItem = nil }
        guard let item, viewModel.canAddVideo else { return }

        if let movie = try? await item.loadTransferable(type: VideoFileTransfer.self) {
            let media = PostComposerMediaItem(
                kind: .video,
                localURL: movie.url,
                width: 0,
                height: 0,
                deepSynth: false
            )
            _ = viewModel.addVideo(media)
        }
    }

    private func imageDimensions(from data: Data) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return (0, 0)
        }
        return (width, height)
    }
}

private struct VideoFileTransfer: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}

#Preview {
    NavigationStack {
        PostComposerView(
            viewModel: PostComposerViewModel(
                baby: BabyProfile(
                    id: "bb_preview",
                    familyId: "fam_preview",
                    name: "豆豆",
                    birthDate: "2024-01-01"
                ),
                aiPlayName: "吉卜力风",
                postService: PreviewPostService()
            )
        )
    }
}

private struct PreviewPostService: PostServing {
    func publish(_ context: PostPublishContext) async throws -> PostCreateData {
        PostCreateData(postId: "pst_preview", status: "published", createdAt: "2026-06-06T00:00:00Z")
    }

    func withdraw(postId: String) async throws -> PostDeleteData {
        PostDeleteData(postId: postId, status: "removed", deletedAt: "2026-06-06T00:00:00Z")
    }
}
