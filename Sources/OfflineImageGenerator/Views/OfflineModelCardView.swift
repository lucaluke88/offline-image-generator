import SwiftUI

/// Dedicated UI component displaying the active offline AI model, architecture, hardware compute units,
/// local folder selection, and integrated Hugging Face CoreML downloader.
struct OfflineModelCardView: View {
    @ObservedObject var viewModel: ImageGeneratorViewModel
    @State private var showDownloaderSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Offline AI Model", systemImage: "cpu.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                statusBadge
            }

            Divider()

            // Active Model Details
            if let model = viewModel.currentModel {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "cube.box.fill")
                            .foregroundStyle(.blue)
                        Text(model.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(model.totalSizeFormatted)
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 8) {
                        badgeTag(text: model.architecture.rawValue, icon: "square.stack.3d.up")
                        if model.isChunkedUnet {
                            badgeTag(text: "Chunked UNet", icon: "memorychip")
                        }
                    }

                    Text(model.directoryURL.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(model.directoryURL.path)

                    DisclosureGroup("Model Bundles (\(model.components.count))") {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(model.components, id: \.self) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: item.hasSuffix(".mlmodelc") ? "shippingbox.fill" : "doc.text.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(item)
                                        .font(.caption.monospaced())
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .font(.caption)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Offline Model Selected")
                            .font(.subheadline.weight(.medium))
                        Text("Select a local CoreML folder or download an Apple CoreML model.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
            }

            // Discovered Local Models Quick Switcher
            if !viewModel.discoveredLocalModels.isEmpty {
                Menu {
                    ForEach(viewModel.discoveredLocalModels) { localModel in
                        Button {
                            viewModel.selectModelDirectory(localModel.directoryURL)
                        } label: {
                            Text("\(localModel.name) (\(localModel.totalSizeFormatted))")
                        }
                    }
                } label: {
                    Label("Switch Downloaded Model (\(viewModel.discoveredLocalModels.count))", systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
            }

            // Action Buttons: Choose Local Folder / Download from Hugging Face
            HStack(spacing: 8) {
                Button {
                    viewModel.chooseModelFolderViaOpenPanel()
                } label: {
                    Label("Load Folder...", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isGenerating || viewModel.isLoadingModel)

                Button {
                    showDownloaderSheet.toggle()
                } label: {
                    Label("Download Model...", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(viewModel.isGenerating)
            }

            // Hardware Acceleration Settings
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple Silicon Compute Units")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("Compute Units", selection: $viewModel.computeUnitSelection) {
                    ForEach(ComputeUnitSelection.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: viewModel.computeUnitSelection) { _, _ in
                    viewModel.isModelLoadedInMemory = false
                }

                Toggle("Reduce Memory Mode (Lazy Load)", isOn: $viewModel.reduceMemoryMode)
                    .font(.caption)
                    .onChange(of: viewModel.reduceMemoryMode) { _, _ in
                        viewModel.isModelLoadedInMemory = false
                    }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .sheet(isPresented: $showDownloaderSheet) {
            ModelDownloaderSheet(viewModel: viewModel, isPresented: $showDownloaderSheet)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if viewModel.isLoadingModel {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Loading...")
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
        } else if viewModel.isModelLoadedInMemory {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Ready Offline")
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(.green)
            .clipShape(Capsule())
        } else if viewModel.currentModel != nil {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.teal)
                    .frame(width: 6, height: 6)
                Text("On Disk")
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.teal.opacity(0.15))
            .foregroundStyle(.teal)
            .clipShape(Capsule())
        } else {
            Text("Not Loaded")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        }
    }

    private func badgeTag(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.accentColor.opacity(0.12))
        .foregroundStyle(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// Sheet for downloading Apple's official CoreML Stable Diffusion models for offline use
struct ModelDownloaderSheet: View {
    @ObservedObject var viewModel: ImageGeneratorViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Download Apple CoreML Model", systemImage: "arrow.down.doc.fill")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Close") {
                    isPresented = false
                }
            }

            Text("Download a pre-compiled CoreML model from Apple's Hugging Face repository. Once downloaded, the model runs 100% offline on your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(DownloadableModelPreset.presets) { preset in
                    let isSelected = viewModel.selectedDownloadPreset == preset
                    Button {
                        if !viewModel.isDownloadingModel {
                            viewModel.selectedDownloadPreset = preset
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(preset.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(preset.estimatedSize)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(preset.repoID)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.isDownloadingModel || !viewModel.downloadStatusText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: viewModel.downloadProgress, total: 1.0)
                    Text(viewModel.downloadStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack {
                Text("Storage: ~/Library/Application Support/OfflineImageGenerator/Models")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()

                if viewModel.isDownloadingModel {
                    Button("Cancel Download", role: .destructive) {
                        viewModel.cancelDownload()
                    }
                } else {
                    Button {
                        viewModel.downloadSelectedPreset()
                    } label: {
                        Label("Download Selected Model", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
