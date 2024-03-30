import Orgel
import SwiftUI

struct ObjectRelationCell: View {
    let name: Relation.Name
    let action: (Relation.Name) -> Void

    var body: some View {
        Button(
            action: {
                action(name)
            },
            label: {
                TextNavigationCell(text: name.description)
            }
        )
        .foregroundColor(.primary)
    }
}

#Preview {
    List {
        ObjectRelationCell(
            name: .init("short title"), action: { name in print("Short name cell tapped.") })
        ObjectRelationCell(
            name: .init("long long long long long long long long long title"),
            action: { name in print("Long name cell tapped.") })
    }
}
