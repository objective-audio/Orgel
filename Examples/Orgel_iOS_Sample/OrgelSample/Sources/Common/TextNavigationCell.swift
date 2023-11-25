import SwiftUI

struct TextNavigationCell: View {
    let text: String

    var body: some View {
        HStack {
            Text(verbatim: text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    List {
        TextNavigationCell(text: "short text")
        TextNavigationCell(text: "long long long long long long long long long long text")
    }
}
