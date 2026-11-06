import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ImageGeneratorViewModel: ObservableObject {

    // MARK: - Model State
    @Published var currentModel: OfflineModelInfo?
    @Published var discoveredLocalModels: [OfflineModelInfo] = []
    @Published var computeUnitSelection: ComputeUnitSelection = .cpuAndNeuralEngine
    @Published var reduceMemoryMode: Bool = false
    @Published var isLoadingModel: Bool = false
    @Published var isModelLoadedInMemory: Bool = false

    // MARK: - Hugging Face Downloader State
    @Published var selectedDownloadPreset: DownloadableModelPreset = DownloadableModelPreset.presets[0]
    @Published var isDownloadingModel: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatusText: String = ""

    // MARK: - Prompt & Generation Parameters
    @Published var prompt: String = "A futuristic glass observatory atop an alpine peak at golden hour, dramatic volumetric lighting, ultra-detailed digital art, 8k"
    @Published var negativePrompt: String = "blurry, low quality, distorted, watermark, oversaturated, deformed"
    @Published var stepCount: Double = 25
    @Published var guidanceScale: Double = 7.5
    @Published var seed: UInt32 = UInt32.random(in: 1...999_999_999)
    @Published var randomizeSeedEachRun: Bool = true
    @Published var scheduler: SchedulerOption = .dpmSolver
    @Published var disableSafetyChecker: Bool = false
    @Published var showIntermediatePreviews: Bool = true

    // MARK: - Output & Progress State
    @Published var isGenerating: Bool = false
    @Published var currentStep: Int = 0
    @Published var totalSteps: Int = 0
    @Published var statusMessage: String = "Select or download an offline CoreML model to begin."
    @Published var errorMessage: String?
    @Published var generatedCGImage: CGImage?
    @Published var generatedNSImage: NSImage?
    @Published var lastGenerationDurationSeconds: Double?
    @Published var lastUsedSeed: UInt32?

    private let sdService = StableDiffusionService()
    private let downloader = HuggingFaceModelDownloader()
    private var downloadTask: Task<Void, Never>?

    private let lastModelPathDefaultsKey = "OfflineImageGenerator.LastModelDirectoryPath"

    init() {
        scanLocalModelsDirectory()
        restoreLastUsedModelIfAvailable()
    }

    // MARK: - Local Model Discovery & Selection

    func scanLocalModelsDirectory() {
        let rootDir = HuggingFaceModelDownloader.defaultModelsRootDirectory
        let fm = FileManager.default
        guard let subdirs = try? fm.contentsOfDirectory(
            at: rootDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            discoveredLocalModels = []
            return
        }

        var found: [OfflineModelInfo] = []
        for dir in subdirs {
            if let info = try? ModelDirectoryInspector.inspect(directoryURL: dir) {
                found.append(info)
            }
        }
        discoveredLocalModels = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func restoreLastUsedModelIfAvailable() {
        if let savedPath = UserDefaults.standard.string(forKey: lastModelPathDefaultsKey) {
            let url = URL(fileURLWithPath: savedPath)
            if let info = try? ModelDirectoryInspector.inspect(directoryURL: url) {
                currentModel = info
                statusMessage = "Model '\(info.name)' detected on disk. Ready to load or generate."
                return
            }
        }
        if let first = discoveredLocalModels.first {
            currentModel = first
            statusMessage = "Model '\(first.name)' found in local storage."
        }
    }

    func chooseModelFolderViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Select CoreML Stable Diffusion Model Folder"
        panel.message = "Choose a directory containing compiled CoreML files (.mlmodelc, vocab.json, merges.txt)"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let selectedURL = panel.url {
            selectModelDirectory(selectedURL)
        }
    }

    func selectModelDirectory(_ url: URL) {
        errorMessage = nil
        do {
            let info = try ModelDirectoryInspector.inspect(directoryURL: url)
            currentModel = info
            isModelLoadedInMemory = false
            UserDefaults.standard.set(info.directoryURL.path, forKey: lastModelPathDefaultsKey)
            statusMessage = "Selected offline model: \(info.name) (\(info.totalSizeFormatted))"
            Task {
                await preloadSelectedModel()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func preloadSelectedModel() async {
        guard let model = currentModel else { return }
        isLoadingModel = true
        errorMessage = nil
        statusMessage = "Loading CoreML pipeline '\(model.name)' into \(computeUnitSelection.rawValue)..."

        do {
            try await sdService.loadModel(
                from: model,
                computeUnits: computeUnitSelection.mlComputeUnits,
                reduceMemory: reduceMemoryMode
            )
            isModelLoadedInMemory = true
            statusMessage = "Offline model '\(model.name)' ready on Apple Silicon."
        } catch {
            isModelLoadedInMemory = false
            errorMessage = "Failed to load CoreML model: \(error.localizedDescription)"
            statusMessage = "Model load failed."
        }
        isLoadingModel = false
    }

    // MARK: - Built-in Hugging Face Model Downloader

    func downloadSelectedPreset() {
        guard !isDownloadingModel else { return }
        let preset = selectedDownloadPreset
        isDownloadingModel = true
        downloadProgress = 0.01
        downloadStatusText = "Starting download of \(preset.displayName)..."
        errorMessage = nil

        downloadTask = Task {
            do {
                let downloadedURL = try await downloader.downloadPreset(preset) { [weak self] fraction, status in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = fraction
                        self?.downloadStatusText = status
                    }
                }
                scanLocalModelsDirectory()
                selectModelDirectory(downloadedURL)
                isDownloadingModel = false
                downloadStatusText = "Downloaded \(preset.displayName) for offline use."
            } catch is CancellationError {
                isDownloadingModel = false
                downloadStatusText = "Download cancelled."
            } catch {
                isDownloadingModel = false
                errorMessage = "Download failed: \(error.localizedDescription)"
                downloadStatusText = "Download failed."
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
    }

    // MARK: - Image Generation

    func generateImage() {
        guard !isGenerating else { return }
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            errorMessage = "Please enter a text prompt to generate an image."
            return
        }
        guard let model = currentModel else {
            errorMessage = "Please select or download an offline CoreML model first."
            return
        }

        errorMessage = nil
        isGenerating = true

        if randomizeSeedEachRun {
            seed = UInt32.random(in: 1...999_999_999)
        }
        let activeSeed = seed
        let steps = Int(stepCount)
        currentStep = 0
        totalSteps = steps
        lastGenerationDurationSeconds = nil

        let params = GenerationParameters(
            prompt: trimmedPrompt,
            negativePrompt: negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            stepCount: steps,
            guidanceScale: Float(guidanceScale),
            seed: activeSeed,
            scheduler: scheduler,
            disableSafety: disableSafetyChecker,
            showIntermediatePreviews: showIntermediatePreviews
        )

        Task { [weak self] in
            guard let self else { return }
            let startTime = Date()
            do {
                if !self.isModelLoadedInMemory {
                    self.isLoadingModel = true
                    self.statusMessage = "Compiling & loading '\(model.name)' onto Apple Silicon..."
                    try await self.sdService.loadModel(
                        from: model,
                        computeUnits: self.computeUnitSelection.mlComputeUnits,
                        reduceMemory: self.reduceMemoryMode
                    )
                    self.isModelLoadedInMemory = true
                    self.isLoadingModel = false
                }

                self.statusMessage = "Generating image offline (Step 0/\(steps))..."

                let finalCGImage = try await self.sdService.generateImage(parameters: params) { [weak self] update in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.currentStep = update.step
                        self.totalSteps = update.totalSteps
                        self.statusMessage = "Generating image offline (Step \(update.step)/\(update.totalSteps))..."
                        if let preview = update.previewImage {
                            self.generatedCGImage = preview
                            self.generatedNSImage = NSImage(
                                cgImage: preview,
                                size: NSSize(width: preview.width, height: preview.height)
                            )
                        }
                    }
                }

                let elapsed = Date().timeIntervalSince(startTime)
                self.generatedCGImage = finalCGImage
                self.generatedNSImage = NSImage(
                    cgImage: finalCGImage,
                    size: NSSize(width: finalCGImage.width, height: finalCGImage.height)
                )
                self.lastGenerationDurationSeconds = elapsed
                self.lastUsedSeed = activeSeed
                self.statusMessage = String(format: "Generated %dx%d image in %.1fs (Seed: %u)", finalCGImage.width, finalCGImage.height, elapsed, activeSeed)
            } catch {
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Generation stopped."
            }
            self.isLoadingModel = false
            self.isGenerating = false
        }
    }

    func cancelGeneration() {
        sdService.requestCancellation()
        statusMessage = "Cancelling generation..."
    }

    // MARK: - Download / Save Image to Disk

    func saveGeneratedImageToDisk() {
        guard let cgImage = generatedCGImage else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "Download Generated Image"
        savePanel.message = "Choose where to save your AI-generated image"
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.canCreateDirectories = true

        let sanitizedPrompt = prompt
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(5)
            .joined(separator: "-")
            .lowercased()
        let baseName = sanitizedPrompt.isEmpty ? "ai-image" : sanitizedPrompt
        savePanel.nameFieldStringValue = "\(baseName)-\(lastUsedSeed ?? seed).png"

        guard savePanel.runModal() == .OK, let targetURL = savePanel.url else {
            return
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let ext = targetURL.pathExtension.lowercased()
        let fileType: NSBitmapImageRep.FileType = (ext == "jpg" || ext == "jpeg") ? .jpeg : .png
        let properties: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg ? [.compressionFactor: 0.95] : [:]

        guard let imageData = bitmapRep.representation(using: fileType, properties: properties) else {
            errorMessage = "Could not encode the image for saving."
            return
        }

        do {
            try imageData.write(to: targetURL, options: .atomic)
            statusMessage = "Saved image to \(targetURL.lastPathComponent)"
        } catch {
            errorMessage = "Failed to save image: \(error.localizedDescription)"
        }
    }
}
