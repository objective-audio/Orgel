import SwiftUI

public struct OrgelSampleView: View {
    public var body: some View {
        RootView(presenter: RootPresenter(lifecycle: .shared))
    }

    public init() {}
}

#Preview {
    OrgelSampleView()
}
