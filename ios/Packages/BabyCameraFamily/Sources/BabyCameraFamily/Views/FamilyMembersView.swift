import DesignSystem
import SwiftUI

public struct FamilyMembersView: View {
    @ObservedObject private var viewModel: FamilyMembersViewModel
    @State private var showInviteSheet = false
    @State private var showTransferFlow = false
    @State private var showTakeoverFlow = false

    private let onJoinFamily: () -> Void

    public init(
        viewModel: FamilyMembersViewModel,
        onJoinFamily: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onJoinFamily = onJoinFamily
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.members.isEmpty {
                DSLoadingView(message: "加载成员…")
            } else if viewModel.members.isEmpty, viewModel.errorMessage != nil {
                DSEmptyState(
                    systemImage: "person.3.fill",
                    title: "加载失败",
                    message: viewModel.errorMessage ?? "",
                    actionTitle: "重试"
                ) {
                    Task { await viewModel.load() }
                }
            } else {
                memberList
            }
        }
        .navigationTitle(viewModel.familyName.isEmpty ? "家庭成员" : viewModel.familyName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.canInvite {
                    Button("邀请") { showInviteSheet = true }
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheet(
                viewModel: InviteViewModel(
                    familyId: viewModel.familyId,
                    familyService: viewModel.familyService
                )
            )
        }
        .sheet(isPresented: $showTransferFlow) {
            TransferAdminFlow(
                viewModel: TransferAdminViewModel(
                    familyId: viewModel.familyId,
                    familyName: viewModel.familyName,
                    candidates: viewModel.transferCandidates,
                    familyService: viewModel.familyService
                ),
                onCompleted: {
                    Task { await viewModel.load() }
                }
            )
        }
        .sheet(isPresented: $showTakeoverFlow) {
            TakeoverFlow(
                viewModel: TakeoverViewModel(
                    familyId: viewModel.familyId,
                    familyName: viewModel.familyName,
                    isAdmin: viewModel.isAdmin,
                    currentRole: viewModel.currentRole,
                    familyService: viewModel.familyService
                ),
                onCompleted: {
                    Task { await viewModel.load() }
                }
            )
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .alert("提示", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var memberList: some View {
        List {
            Section {
                ForEach(viewModel.members) { member in
                    DSListRow(
                        icon: roleIcon(member.role),
                        title: member.nickname.isEmpty ? member.role.displayName : member.nickname,
                        subtitle: member.role.displayName,
                        showsDivider: true
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.isAdmin, member.role != .admin {
                            Button(role: .destructive) {
                                Task { await viewModel.removeMember(member) }
                            } label: {
                                Label("移除", systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
            } header: {
                Text("成员 (\(viewModel.members.count))")
            }

            Section {
                Button {
                    onJoinFamily()
                } label: {
                    Label("加入其他家庭", systemImage: "person.badge.plus")
                }
            }

            if viewModel.isAdmin {
                Section("管理员") {
                    Button {
                        showTransferFlow = true
                    } label: {
                        Label("转让管理员", systemImage: "arrow.triangle.swap")
                    }
                    .disabled(viewModel.transferCandidates.isEmpty)
                }
            } else if viewModel.currentRole == .family {
                Section("管理员") {
                    Button {
                        showTakeoverFlow = true
                    } label: {
                        Label("管理员失联接管", systemImage: "person.badge.shield.checkmark")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func roleIcon(_ role: FamilyRole) -> String {
        switch role {
        case .admin: "crown.fill"
        case .family: "person.fill"
        case .guest: "eye.fill"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.members.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
