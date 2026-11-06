import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ImageGeneratorViewModel()

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Offline AI Model Inspector & Selector Component
                    OfflineModelCardView(viewModel: viewModel)

                    // 2. Prompt Text Box & Generation Controls Component
                    PromptInputPanelView(viewModel: viewModel)
                }
                .padding(14)
            }
            .navigationSplitViewColumnWidth(min: 350, ideal: 380, max: 450)
        } detail: {
            // 3. Generated Image Preview & Download Button Component
            ImagePreviewPanelView(viewModel: viewModel)
                .frame(minWidth: 520, minHeight: 560)
        }
        .navigationTitle("Offline AI Image Generator — Apple Silicon")
    }
}
