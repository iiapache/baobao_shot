import SwiftUI

public struct CustomMilestoneListView: View {
    @ObservedObject private var viewModel: CustomMilestoneViewModel
    @State private var selectedDayKey: String?
    @State private var showingCreateSheet = false
    @State private var draftName = ""
    @State private var draftDate = Date()

    public init(viewModel: CustomMilestoneViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            MilestoneCalendarView(
                markedDayKeys: viewModel.calendarMarkedDays,
                selectedDayKey: selectedDayKey,
                onSelectDay: { dayKey in
                    selectedDayKey = dayKey
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            listContent
        }
        .accessibilityIdentifier("customMilestoneListView")
        .task {
            await viewModel.reload()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("添加") {
                    draftName = ""
                    draftDate = Date()
                    showingCreateSheet = true
                }
                .accessibilityIdentifier("addCustomMilestoneButton")
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                Form {
                    TextField("里程碑名称", text: $draftName)
                    DatePicker("日期", selection: $draftDate, displayedComponents: .date)
                }
                .navigationTitle("新建里程碑")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task {
                                if await viewModel.create(name: draftName, date: draftDate) != nil {
                                    showingCreateSheet = false
                                }
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading && viewModel.entries.isEmpty {
            ProgressView("加载里程碑…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.entries.isEmpty {
            ContentUnavailableView(
                "无法加载",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else {
            List {
                if let selectedDayKey {
                    Section("选中日期") {
                        ForEach(viewModel.entries(on: selectedDayKey)) { entry in
                            milestoneRow(entry)
                        }
                    }
                }

                Section("全部里程碑") {
                    ForEach(viewModel.entries) { entry in
                        milestoneRow(entry)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let entry = viewModel.entries[index]
                                if case let .custom(milestone) = entry {
                                    _ = await viewModel.delete(id: milestone.id)
                                }
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("customMilestoneList")
        }
    }

    @ViewBuilder
    private func milestoneRow(_ entry: MilestoneTimelineEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.body)
                Text(entry.dayKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if entry.isCustom {
                Text("自定义")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Text("内置")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .accessibilityIdentifier("milestoneRow.\(entry.id)")
    }
}
