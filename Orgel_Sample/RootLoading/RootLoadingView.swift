import SwiftUI

struct RootLoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(.large)
    }
}

#Preview {
    RootLoadingView()
}
