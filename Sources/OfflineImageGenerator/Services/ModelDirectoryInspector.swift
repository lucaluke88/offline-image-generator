import Foundation

/// Inspects local directories to validate and summarize CoreML Stable Diffusion models
enum ModelDirectoryInspector {

    enum InspectionError: LocalizedError {
        case directoryNotFound
        case missingRequiredComponents([String])

        var errorDescription: String? {
            switch self {
            case .directoryNotFound:
                return "The selected folder does not exist or cannot be accessed."
            case .missingRequiredComponents(let missing):
                return "Invalid CoreML Stable Diffusion folder. Missing: \(missing.joined(separator: ", "))"
            }
        }
    }

    /// Inspects a folder (or searches one level deep if the user selected a parent archive folder)
    static func inspect(directoryURL: URL) throws -> OfflineModelInfo {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw InspectionError.directoryNotFound
        }

        // Check if the directory itself contains the CoreML bundles, or if a subdirectory does
        let resolvedURL = resolveResourceDirectory(from: directoryURL)

        let contents = (try? fm.contentsOfDirectory(atPath: resolvedURL.path)) ?? []
        let contentSet = Set(contents)

        let hasUnet = contentSet.contains("Unet.mlmodelc")
        let hasChunkedUnet = contentSet.contains("UnetChunk1.mlmodelc") && contentSet.contains("UnetChunk2.mlmodelc")
        let hasVAEDecoder = contentSet.contains("VAEDecoder.mlmodelc")
        let hasTextEncoder = contentSet.contains("TextEncoder.mlmodelc")
        let hasTextEncoder2 = contentSet.contains("TextEncoder2.mlmodelc")
        let hasVocab = contentSet.contains("vocab.json")
        let hasMerges = contentSet.contains("merges.txt")

        var missing: [String] = []
        if !hasUnet && !hasChunkedUnet {
            missing.append("Unet.mlmodelc (or UnetChunk1/2.mlmodelc)")
        }
        if !hasVAEDecoder {
            missing.append("VAEDecoder.mlmodelc")
        }
        if !hasTextEncoder && !hasTextEncoder2 {
            missing.append("TextEncoder.mlmodelc")
        }
        if !hasVocab {
            missing.append("vocab.json")
        }
        if !hasMerges {
            missing.append("merges.txt")
        }

        if !missing.isEmpty {
            throw InspectionError.missingRequiredComponents(missing)
        }

        let architecture: ModelArchitecture = hasTextEncoder2 ? .stableDiffusionXL : .stableDiffusion

        let detectedComponents = contents.filter {
            $0.hasSuffix(".mlmodelc") || $0 == "vocab.json" || $0 == "merges.txt"
        }.sorted()

        let hasSafetyChecker = contentSet.contains("SafetyChecker.mlmodelc")
        let totalSizeBytes = directorySize(at: resolvedURL)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        let sizeString = formatter.string(fromByteCount: Int64(totalSizeBytes))

        let displayName = resolvedURL.lastPathComponent == "compiled" || resolvedURL.lastPathComponent == "Resources"
            ? directoryURL.lastPathComponent
            : resolvedURL.lastPathComponent

        return OfflineModelInfo(
            name: displayName,
            directoryURL: resolvedURL,
            architecture: architecture,
            components: detectedComponents,
            isChunkedUnet: hasChunkedUnet,
            hasSafetyChecker: hasSafetyChecker,
            totalSizeFormatted: sizeString
        )
    }

    /// Searches up to 2 levels deep for a directory containing `VAEDecoder.mlmodelc`
    private static func resolveResourceDirectory(from rootURL: URL) -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: rootURL.appendingPathComponent("VAEDecoder.mlmodelc").path) {
            return rootURL
        }

        // Common nested paths in Apple Hugging Face repositories
        let candidateSubpaths = [
            "original/compiled",
            "split_einsum/compiled",
            "compiled",
            "Resources"
        ]
        for subpath in candidateSubpaths {
            let candidate = rootURL.appendingPathComponent(subpath)
            if fm.fileExists(atPath: candidate.appendingPathComponent("VAEDecoder.mlmodelc").path) {
                return candidate
            }
        }

        // Check immediate subdirectories
        if let subdirs = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for subdir in subdirs {
                if fm.fileExists(atPath: subdir.appendingPathComponent("VAEDecoder.mlmodelc").path) {
                    return subdir
                }
            }
        }

        return rootURL
    }

    private static func directorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true,
               let fileSize = values.fileSize {
                total += UInt64(fileSize)
            }
        }
        return total
    }
}
