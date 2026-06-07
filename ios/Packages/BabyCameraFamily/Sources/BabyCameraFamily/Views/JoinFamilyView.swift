import DesignSystem
import SwiftUI

public struct JoinFamilyView: View {
    @ObservedObject private var viewModel: JoinFamilyViewModel
    @State private var showScanner = false

    private let onJoined: (JoinFamilyResult) -> Void

    public init(
        viewModel: JoinFamilyViewModel,
        onJoined: @escaping (JoinFamilyResult) -> Void
    ) {
        self.viewModel = viewModel
        self.onJoined = onJoined
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                header
                inviteCodeSection
                relationSection
                nicknameSection
                submitSection
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColors.background)
        .navigationTitle("加入家庭")
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                onScan: { content in
                    viewModel.handleScannedContent(content)
                    showScanner = false
                },
                onCancel: { showScanner = false }
            )
            .ignoresSafeArea()
        }
        .alert("加入失败", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(DSColors.primary)
            Text("输入邀请码或扫码加入")
                .font(DSTypography.subheadline)
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.md)
    }

    private var inviteCodeSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("邀请码")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            HStack(spacing: DSSpacing.sm) {
                TextField("6 位数字邀请码", text: $viewModel.inviteCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(DSSpacing.md)
                    .background(DSColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))

                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundStyle(DSColors.primary)
                        .frame(width: 48, height: 48)
                        .background(DSColors.primaryMuted)
                        .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
                }
                .accessibilityLabel("扫描二维码")
            }
        }
    }

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("与宝宝的关系")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: DSSpacing.sm)],
                spacing: DSSpacing.sm
            ) {
                ForEach(FamilyRelation.allCases) { relation in
                    relationChip(relation)
                }
            }
        }
    }

    private func relationChip(_ relation: FamilyRelation) -> some View {
        let isSelected = viewModel.selectedRelation == relation
        return Button {
            viewModel.selectedRelation = relation
        } label: {
            Text(relation.displayName)
                .font(DSTypography.caption)
                .foregroundStyle(isSelected ? DSColors.textOnPrimary : DSColors.textPrimary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .frame(maxWidth: .infinity)
                .background(isSelected ? DSColors.primary : DSColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("在家庭中的称呼（可选）")
                .font(DSTypography.caption)
                .foregroundStyle(DSColors.textSecondary)

            TextField("如：豆豆妈", text: $viewModel.nickname)
                .padding(DSSpacing.md)
                .background(DSColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DSSpacing.cardCornerRadius))
        }
    }

    private var submitSection: some View {
        DSButton(
            "加入家庭",
            style: .primary,
            isLoading: viewModel.isLoading,
            isDisabled: !viewModel.canSubmit
        ) {
            Task {
                if let result = await viewModel.join() {
                    onJoined(result)
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
