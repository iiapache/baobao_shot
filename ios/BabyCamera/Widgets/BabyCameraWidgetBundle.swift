import SwiftUI
import WidgetKit

@main
struct BabyCameraWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyCameraSmallWidget()
        BabyCameraMediumWidget()
        BabyCameraLargeWidget()
        BabyCameraLockScreenWidget()
    }
}
