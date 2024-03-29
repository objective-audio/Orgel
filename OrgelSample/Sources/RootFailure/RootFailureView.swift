import SwiftUI

struct RootFailureView: View {
    let error: Error

    var body: some View {
        VStack {
            Text(Localized.RootFailureView.databaseSetupFailedTitle)
                .padding(.bottom, 8)
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootFailureView(error: NSError(domain: "domain", code: 0))
}
