import SwiftUI
import AppKit

/// Component displaying the generated image preview, real-time denoising progress,
/// metadata badges, and the download/export button.
struct ImagePreviewPanelView: View {
    @ObservedObject var viewModel: ImageGeneratorViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Top Bar: Title, Metadata & Download Button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generated Image Preview")
                        .font(.title3.weight(.semibold))
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let nsImage = viewModel.generatedNSImage {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([nsImage])
                        viewModel.statusMessage = "Copied image to clipboard."
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(viewModel.isGenerating)
                }

                Button {
                    viewModel.saveGeneratedImageToDisk()
                } label: {
                    Label("Download Image", systemImage: "arrow.down.to.line.compact")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.generatedCGImage == nil || viewModel.isGenerating)
                .keyboardShortcut("s", modifiers: [.command])
            }

            // Error Alert Banner if present
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .controlSize(.mini)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
            }

            // Main Image Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                if let nsImage = viewModel.generatedNSImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        .padding(16)
                } else if !viewModel.isGenerating {
                    emptyCanvasPlaceholder
                }

                // Denoising Progress Overlay
                if viewModel.isGenerating {
                    generatingProgressOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Footer: Image Metadata & Active Model Pill
            footerMetadataBar
        }
        .padding(20)
    }

    private var emptyCanvasPlaceholder: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "photo.artframe")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.accentColor)
            }

            Text("Ready to Generate Offline")
                .font(.headline)

            Text("Select or download a local CoreML Stable Diffusion model on the left,\nwrite your prompt, and click Generate Image Offline (⌘↩).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(32)
    }

    private var generatingProgressOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(
                value: Double(viewModel.currentStep),
                total: Double(max(1, viewModel.totalSteps))
            )
            .progressViewStyle(.linear)
            .frame(width: 260)

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                if viewModel.isLoadingModel {
                    Text("Preparing Apple Silicon CoreML Pipeline...")
                        .font(.caption.weight(.medium))
                } else {
                    Text("Denoising Step \(viewModel.currentStep) of \(viewModel.totalSteps)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }

    private var footerMetadataBar: some View {
        HStack(spacing: 16) {
            if let model = viewModel.currentModel {
                Label("Model: \(model.name)", systemImage: "cpu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Model: None loaded", systemImage: "cpu")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let cgImage = viewModel.generatedCGImage {
                Divider().frame(height: 12)
                Label("\(cgImage.width) × \(cgImage.height) px", systemImage: "aspectratio")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let usedSeed = viewModel.lastUsedSeed {
                Divider().frame(height: 12)
                Label("Seed: \(usedSeed)", systemImage: "number")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let duration = viewModel.lastGenerationDurationSeconds {
                Divider().frame(height: 12)
                Label(String(format: "%.1fs", duration), systemImage: "bolt.fill")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("100% Local On-Device Inference")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
        }
    }
}
