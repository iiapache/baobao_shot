import DesignSystem
import PhotosUI
import SwiftUI

public struct BabySwitcherView: View {
    @ObservedObject private var currentBabyStore: CurrentBabyEnvironment
    private let onAddBaby: () -> Void
    private let onSelectBaby: (BabyProfile) -> Void

    public init(
        currentBabyStore: CurrentBabyEnvironment,
        onAddBaby: @escaping () -> Void = {},
        onSelectBaby: @escaping (BabyProfile) -> Void = { _ in }
    ) {
        self.currentBabyStore = currentBabyStore
        self.onAddBaby = onAddBaby
        self.onSelectBaby = onSelectBaby
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.sm) {
                ForEach(currentBabyStore.babies) { baby in
                    babyItem(for: baby)
                }
                addButton
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
        }
        .accessibilityIdentifier("babySwitcher")
    }

    private func babyItem(for baby: BabyProfile) -> some View {
        let isSelected = currentBabyStore.currentBaby?.id == baby.id

        return Button {
            currentBabyStore.select(babyId: baby.id)
            onSelectBaby(baby)
        } label: {
            VStack(spacing: DSSpacing.xxs) {
                BabyAvatarView(
                    name: baby.name,
                    avatarURL: baby.avatarURL,
                    size: 56,
                    isSelected: isSelected
                )
                Text(baby.name)
                    .font(DSTypography.caption)
                    .foregroundStyle(isSelected ? DSColors.primary : DSColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(baby.name)，\(BabyAgeFormatter.displayAge(birthDate: baby.birthDate))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var addButton: some View {
        Button(action: onAddBaby) {
            VStack(spacing: DSSpacing.xxs) {
                ZStack {
                    Circle()
                        .strokeBorder(DSColors.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(DSColors.primary)
                }
                Text("添加")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSColors.textSecondary)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加宝宝")
    }
}

struct BabyAvatarView: View {
    let name: String
    let avatarURL: String?
    let size: CGFloat
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            if let avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(isSelected ? DSColors.primary : Color.clear, lineWidth: 3)
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(DSColors.primaryMuted)
            Text(String(name.prefix(1)))
                .font(DSTypography.title3)
                .foregroundStyle(DSColors.primary)
        }
    }
}

#Preview {
    let store = CurrentBabyEnvironment(restorePersistedSelection: false)
    store.replaceBabies([
        BabyProfile(id: "1", familyId: "fam", name: "豆豆", birthDate: "2024-01-15"),
        BabyProfile(id: "2", familyId: "fam", name: "糖糖", birthDate: "2022-06-01", gender: .female),
    ])
    return BabySwitcherView(currentBabyStore: store)
}
