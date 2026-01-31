import SwiftUI
import AVFoundation

// DRAG & DROP TIMELINE EXPORT DEMO
// This demonstrates the new export timeline functionality
// Once tested, this code would be integrated into ExportManagerView.swift

struct ExportTimelineDemo: View {
    @State private var timeline = ExportTimeline(items: [
        ExportItem(
            url: URL(fileURLWithPath: "/example/take1.mov"),
            kind: .take,
            label: "Take 1",
            duration: CMTime(seconds: 30, preferredTimescale: 600),
            included: true
        ),
        ExportItem(
            url: URL(fileURLWithPath: "/example/take2.mov"),
            kind: .take,
            label: "Take 2", 
            duration: CMTime(seconds: 45, preferredTimescale: 600),
            included: true
        ),
        ExportItem(
            url: URL(fileURLWithPath: "/example/slate.mov"),
            kind: .slate,
            label: "Slate",
            duration: CMTime(seconds: 8, preferredTimescale: 600),
            included: true
        )
    ])
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("🎬 Drag & Drop Export Timeline")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Drag to reorder • Tap ✓ to include/exclude")
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                // The new timeline component
                ExportTimelineStrip(items: $timeline.items)
                    .frame(height: 120)
                
                VStack(spacing: 8) {
                    Text("Export Order:")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    ForEach(timeline.items.filter { $0.included }.indices, id: \.self) { index in
                        let item = timeline.items.filter { $0.included }[index]
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.gray)
                            Text(item.label)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(item.duration.asClockString)
                                .foregroundStyle(.gray)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                
                Spacer()
                
                Button("Export \(timeline.items.filter { $0.included }.count) Items") {
                    print("Would export in order:")
                    timeline.items.filter { $0.included }.enumerated().forEach { index, item in
                        print("\(index + 1). \(item.label) - \(item.duration.asClockString)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(timeline.items.filter { $0.included }.isEmpty)
            }
            .padding()
            .background(Color.black)
        }
    }
}

// Integration Instructions:
// 1. Add timeline state to ExportManagerView: @State private var timeline = ExportTimeline(items: [])
// 2. Replace static take preview with: ExportTimelineStrip(items: $timeline.items)  
// 3. Initialize timeline from goodTakes in initializeTimeline()
// 4. Update export logic to use timeline.items.filter { $0.included } in user order
// 5. Remove "Merged with Slate" option since slate positioning handled by drag & drop

#Preview {
    ExportTimelineDemo()
}
