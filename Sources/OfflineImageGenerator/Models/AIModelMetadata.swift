import Foundation
import CoreML

/// Compute unit option for Apple Silicon hardware acceleration
enum ComputeUnitSelection: String, CaseIterable, Identifiable {
    case cpuAndNeuralEngine = "CPU + Neural Engine (Recommended)"
    case cpuAndGPU = "CPU + GPU (Metal)"
    case all = "All (CPU + GPU + ANE)"
    case cpuOnly = "CPU Only"

    var id: String { rawValue }

    var mlComputeUnits: MLComputeUnits {
        switch self {
        case .cpuAndNeuralEngine:
            return .cpuAndNeuralEngine
        case .cpuAndGPU:
            return .cpuAndGPU
        case .all:
            return .all
        case .cpuOnly:
            return .cpuOnly
        }
    }
}

/// Scheduler option for the diffusion denoising loop
enum SchedulerOption: String, CaseIterable, Identifiable {
    case dpmSolver = "DPM-Solver++ (Fast & Sharp)"
    case pndm = "PNDM (Classic)"

    var id: String { rawValue }
}

/// Detected architecture of a local CoreML Stable Diffusion model directory
enum ModelArchitecture: String {
    case stableDiffusion = "Stable Diffusion (1.5 / 2.1)"
    case stableDiffusionXL = "Stable Diffusion XL (SDXL)"
}

/// Metadata representing a loaded or detected local CoreML model
struct OfflineModelInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let directoryURL: URL
    let architecture: ModelArchitecture
    let components: [String]
    let isChunkedUnet: Bool
    let hasSafetyChecker: Bool
    let totalSizeFormatted: String
}

/// Preset downloadable CoreML models hosted by Apple on Hugging Face
struct DownloadableModelPreset: Identifiable, Hashable {
    let id: String
    let displayName: String
    let repoID: String
    let variantPath: String
    let description: String
    let estimatedSize: String

    static let presets: [DownloadableModelPreset] = [
        DownloadableModelPreset(
            id: "sd-v1-5-palettized",
            displayName: "Stable Diffusion v1.5 (6-bit Palettized)",
            repoID: "apple/coreml-stable-diffusion-v1-5-palettized",
            variantPath: "original/compiled",
            description: "Compact, fast Apple CoreML model optimized for Apple Silicon Neural Engine.",
            estimatedSize: "~1.0 GB"
        ),
        DownloadableModelPreset(
            id: "sd-2-1-base-palettized",
            displayName: "Stable Diffusion v2.1 Base (6-bit Palettized)",
            repoID: "apple/coreml-stable-diffusion-2-1-base-palettized",
            variantPath: "original/compiled",
            description: "Higher fidelity base model with 6-bit weight palettization for macOS.",
            estimatedSize: "~1.1 GB"
        ),
        DownloadableModelPreset(
            id: "sd-v1-5-fp16",
            displayName: "Stable Diffusion v1.5 (Float16)",
            repoID: "apple/coreml-stable-diffusion-v1-5",
            variantPath: "original/compiled",
            description: "Full half-precision CoreML compiled packages for maximum quality.",
            estimatedSize: "~2.0 GB"
        )
    ]
}
