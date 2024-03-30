import SwiftUI

struct TextCell: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
    }
}

#Preview {
    List {
        TextCell(text: "short text")
        TextCell(text: "long long long long long long long long long long text")
    }
}
