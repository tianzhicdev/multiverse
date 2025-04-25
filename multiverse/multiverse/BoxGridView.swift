import SwiftUI
import SwiftData

struct BoxGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [UploadItem]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    let totalBoxes = 2
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let rowCount = ceil(Double(totalBoxes) / 3.0)
            let boxHeight = (screenHeight - (4 * (rowCount - 1))) / rowCount
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<totalBoxes, id: \.self) { index in
                        BoxView(number: index + 1, items: items)
                            .frame(height: boxHeight)
                    }
                }
            }
        }
    }
}

#Preview {
    BoxGridView()
        .modelContainer(for: UploadItem.self, inMemory: true)
}
