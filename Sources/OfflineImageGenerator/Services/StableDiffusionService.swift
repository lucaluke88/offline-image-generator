import Foundation
import CoreGraphics
import CoreML
import StableDiffusion

/// Parameters for generating an image offline
struct GenerationParameters: Sendable {
    var prompt: String
    var negativePrompt: String
    var stepCount: Int
    var guidanceScale: Float
    var seed: UInt32
    var scheduler: SchedulerOption
    var disableSafety: Bool
    var showIntermediatePreviews: Bool
}

/// Progress update emitted at each denoising step
struct GenerationStepUpdate: Sendable {
    let step: Int
    let totalSteps: Int
    let previewImage: CGImage?
}

/// Manages local CoreML Stable Diffusion pipeline initialization and inference off the main thread
final class StableDiffusionService: @unchecked Sendable {

    enum ServiceError: LocalizedError {
        case pipelineNotLoaded
        case generationCancelled
        case emptyOutputSafetyFiltered

        var errorDescription: String? {
            switch self {
            case .pipelineNotLoaded:
                return "No offline CoreML model is currently loaded. Please load a model directory first."
            case .generationCancelled:
                return "Image generation was cancelled."
            case .emptyOutputSafetyFiltered:
                return "No image was returned (it may have been filtered by the Safety Checker or interrupted)."
            }
        }
    }

    private let queue = DispatchQueue(label: "com.offlineimagegenerator.sd-pipeline", qos: .userInitiated)
    private var pipeline: StableDiffusionPipelineProtocol?
    private var loadedModelURL: URL?
    private var loadedComputeUnits: MLComputeUnits?
    private var loadedReduceMemory: Bool?

    private let cancellationLock = NSLock()
    private var isCancellationRequested = false

    func requestCancellation() {
        cancellationLock.lock()
        isCancellationRequested = true
        cancellationLock.unlock()
    }

    private func resetCancellation() {
        cancellationLock.lock()
        isCancellationRequested = false
        cancellationLock.unlock()
    }

    private var shouldCancel: Bool {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        return isCancellationRequested
    }

    /// Loads or reloads a local CoreML Stable Diffusion model directory
    func loadModel(
        from modelInfo: OfflineModelInfo,
        computeUnits: MLComputeUnits,
        reduceMemory: Bool
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                do {
                    if self.loadedModelURL == modelInfo.directoryURL,
                       self.loadedComputeUnits == computeUnits,
                       self.loadedReduceMemory == reduceMemory,
                       self.pipeline != nil {
                        continuation.resume()
                        return
                    }

                    self.pipeline?.unloadResources()
                    self.pipeline = nil

                    let config = MLModelConfiguration()
                    config.computeUnits = computeUnits

                    let newPipeline: StableDiffusionPipelineProtocol
                    switch modelInfo.architecture {
                    case .stableDiffusion:
                        newPipeline = try StableDiffusionPipeline(
                            resourcesAt: modelInfo.directoryURL,
                            controlNet: [],
                            configuration: config,
                            disableSafety: false,
                            reduceMemory: reduceMemory
                        )
                    case .stableDiffusionXL:
                        newPipeline = try StableDiffusionXLPipeline(
                            resourcesAt: modelInfo.directoryURL,
                            configuration: config,
                            reduceMemory: reduceMemory
                        )
                    }

                    try newPipeline.loadResources()
                    self.pipeline = newPipeline
                    self.loadedModelURL = modelInfo.directoryURL
                    self.loadedComputeUnits = computeUnits
                    self.loadedReduceMemory = reduceMemory
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Unloads pipeline resources from memory
    func unloadModel() {
        queue.async { [weak self] in
            self?.pipeline?.unloadResources()
            self?.pipeline = nil
            self?.loadedModelURL = nil
        }
    }

    /// Generates an image using the loaded CoreML pipeline
    func generateImage(
        parameters: GenerationParameters,
        onStep: @escaping @Sendable (GenerationStepUpdate) -> Void
    ) async throws -> CGImage {
        resetCancellation()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
            queue.async { [weak self] in
                guard let self else { return }
                guard let activePipeline = self.pipeline else {
                    continuation.resume(throwing: ServiceError.pipelineNotLoaded)
                    return
                }

                do {
                    var config = PipelineConfiguration(prompt: parameters.prompt)
                    config.negativePrompt = parameters.negativePrompt
                    config.stepCount = parameters.stepCount
                    config.guidanceScale = parameters.guidanceScale
                    config.seed = parameters.seed
                    config.disableSafety = parameters.disableSafety
                    config.useDenoisedIntermediates = parameters.showIntermediatePreviews
                    config.schedulerType = parameters.scheduler == .dpmSolver
                        ? .dpmSolverMultistepScheduler
                        : .pndmScheduler

                    let images = try activePipeline.generateImages(configuration: config) { progress in
                        if self.shouldCancel {
                            return false
                        }

                        var intermediateImage: CGImage? = nil
                        if parameters.showIntermediatePreviews && (progress.step % 3 == 0 || progress.step == progress.stepCount - 1) {
                            intermediateImage = progress.currentImages.first ?? nil
                        }

                        onStep(
                            GenerationStepUpdate(
                                step: progress.step + 1,
                                totalSteps: progress.stepCount,
                                previewImage: intermediateImage
                            )
                        )
                        return !self.shouldCancel
                    }

                    if self.shouldCancel {
                        continuation.resume(throwing: ServiceError.generationCancelled)
                        return
                    }

                    guard let firstImage = images.compactMap({ $0 }).first else {
                        continuation.resume(throwing: ServiceError.emptyOutputSafetyFiltered)
                        return
                    }

                    continuation.resume(returning: firstImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
