import SwiftUI

/// Text box component for writing positive/negative prompts and configuring diffusion parameters.
struct PromptInputPanelView: View {
    @ObservedObject var viewModel: ImageGeneratorViewModel

    private let samplePrompts: [String] = [
        "A serene Japanese cyberpunk street in the rain, neon reflections on wet cobblestones, cinematic 35mm photography",
        "An astronaut riding a bioluminescent whale through a cosmic nebula, oil painting, Studio Ghibli & Moebius style",
        "Architectural render of a minimalist Nordic cabin nested in a snowy pine forest at twilight, warm interior glow"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Prompt Header & Sample Presets
            HStack {
                Label("Prompt", systemImage: "text.bubble.fill")
                    .font(.headline)

                Spacer()

                Menu {
                    ForEach(samplePrompts, id: \.self) { sample in
                        Button {
                            viewModel.prompt = sample
                        } label: {
                            Text(sample)
                                .lineLimit(1)
                        }
                    }
                } label: {
                    Label("Ideas", systemImage: "sparkles")
                        .font(.caption)
                }
                .controlSize(.small)
            }

            // Positive Prompt Text Box
            TextEditor(text: $viewModel.prompt)
                .font(.body)
                .frame(minHeight: 88, maxHeight: 120)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )

            // Negative Prompt Text Box
            VStack(alignment: .leading, spacing: 6) {
                Label("Negative Prompt (Optional)", systemImage: "minus.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Things to exclude (e.g., blurry, watermark, low quality)", text: $viewModel.negativePrompt)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            // Generation Parameters
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Inference Steps: \(Int(viewModel.stepCount))")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Slider(value: $viewModel.stepCount, in: 10...50, step: 1)
                        .frame(width: 160)
                }

                HStack {
                    Text(String(format: "Guidance Scale (CFG): %.1f", viewModel.guidanceScale))
                        .font(.caption.weight(.medium))
                    Spacer()
                    Slider(value: $viewModel.guidanceScale, in: 1.0...15.0, step: 0.5)
                        .frame(width: 160)
                }

                Picker("Scheduler", selection: $viewModel.scheduler) {
                    ForEach(SchedulerOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Toggle("Random Seed", isOn: $viewModel.randomizeSeedEachRun)
                        .font(.caption)

                    Spacer()

                    if !viewModel.randomizeSeedEachRun {
                        TextField(
                            "Seed",
                            value: $viewModel.seed,
                            format: .number.grouping(.never)
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                        .font(.caption.monospacedDigit())
                    }
                }

                HStack {
                    Toggle("Live Step Preview", isOn: $viewModel.showIntermediatePreviews)
                        .font(.caption)
                    Spacer()
                    Toggle("Disable Safety Filter", isOn: $viewModel.disableSafetyChecker)
                        .font(.caption)
                }
            }

            // Generate / Cancel Action Button
            HStack(spacing: 10) {
                if viewModel.isGenerating {
                    Button(role: .destructive) {
                        viewModel.cancelGeneration()
                    } label: {
                        Label("Cancel Generation", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                } else {
                    Button {
                        viewModel.generateImage()
                    } label: {
                        Label("Generate Image Offline", systemImage: "wand.and.stars")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.currentModel == nil || viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command])
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
    }
}
