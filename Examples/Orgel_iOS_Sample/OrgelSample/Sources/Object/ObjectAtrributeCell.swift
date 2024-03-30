import SwiftUI

struct ObjectAtrributeCell: View {
    @Bindable var content: ObjectAttributeCellContent

    var body: some View {
        HStack {
            Text(verbatim: content.name.rawValue)
                .frame(minWidth: 100, alignment: .leading)
            TextField("", text: $content.valueText)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    List {
        ObjectAtrributeCell(content: .init(name: .init("title"), object: nil))
    }
}
