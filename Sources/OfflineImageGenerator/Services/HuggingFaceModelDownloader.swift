import Foundation

/// Downloads pre-compiled CoreML Stable Diffusion models from Hugging Face into local storage for offline use
actor HuggingFaceModelDownloader {

    struct TreeEntry: Decodable {
        let type: String
        let path: String
        let size: Int?
    }

    enum DownloadError: LocalizedError {
        case invalidURL
        case badServerResponse(Int)
        case noModelFilesFound

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Could not construct a valid Hugging Face URL."
            case .badServerResponse(let status):
                return "Hugging Face server returned HTTP \(status)."
            case .noModelFilesFound:
                return "No CoreML files were found in the specified Hugging Face repository path."
            }
        }
    }

    /// Default local directory where downloaded offline models are stored
    static var defaultModelsRootDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("OfflineImageGenerator", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    /// Downloads all files under `preset.variantPath` from `preset.repoID` into Application Support
    func downloadPreset(
        _ preset: DownloadableModelPreset,
        progressHandler: @Sendable (Double, String) -> Void
    ) async throws -> URL {
        let destinationRoot = Self.defaultModelsRootDirectory.appendingPathComponent(preset.id, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        progressHandler(0.02, "Fetching file manifest from \(preset.repoID)...")

        let treeURLString = "https://huggingface.co/api/models/\(preset.repoID)/tree/main/\(preset.variantPath)?recursive=true"
        guard let treeURL = URL(string: treeURLString) else {
            throw DownloadError.invalidURL
        }

        let (treeData, response) = try await URLSession.shared.data(from: treeURL)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw DownloadError.badServerResponse(httpResponse.statusCode)
        }

        let entries = try JSONDecoder().decode([TreeEntry].self, from: treeData)
        let fileEntries = entries.filter { $0.type == "file" }

        guard !fileEntries.isEmpty else {
            throw DownloadError.noModelFilesFound
        }

        let totalBytes = max(1, fileEntries.reduce(0) { $0 + ($1.size ?? 0) })
        var downloadedBytes = 0

        let prefixToRemove = preset.variantPath.hasSuffix("/") ? preset.variantPath : preset.variantPath + "/"

        for (index, entry) in fileEntries.enumerated() {
            try Task.checkCancellation()

            let relativePath: String
            if entry.path.hasPrefix(prefixToRemove) {
                relativePath = String(entry.path.dropFirst(prefixToRemove.count))
            } else {
                relativePath = (entry.path as NSString).lastPathComponent
            }

            let localFileURL = destinationRoot.appendingPathComponent(relativePath)
            let parentDir = localFileURL.deletingLastPathComponent()
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

            // Skip already downloaded files with matching size
            if let expectedSize = entry.size,
               let attrs = try? fm.attributesOfItem(atPath: localFileURL.path),
               let existingSize = attrs[.size] as? Int,
               existingSize == expectedSize {
                downloadedBytes += expectedSize
                let fraction = Double(downloadedBytes) / Double(totalBytes)
                progressHandler(min(0.99, fraction), "Verified \(relativePath) (\(index + 1)/\(fileEntries.count))")
                continue
            }

            let encodedPath = entry.path
                .split(separator: "/")
                .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
                .joined(separator: "/")

            guard let fileDownloadURL = URL(string: "https://huggingface.co/\(preset.repoID)/resolve/main/\(encodedPath)") else {
                throw DownloadError.invalidURL
            }

            let fileName = (relativePath as NSString).lastPathComponent
            let currentFraction = Double(downloadedBytes) / Double(totalBytes)
            progressHandler(
                min(0.99, max(0.05, currentFraction)),
                "Downloading \(fileName) (\(index + 1)/\(fileEntries.count))..."
            )

            let (tempURL, fileResponse) = try await URLSession.shared.download(from: fileDownloadURL)
            if let httpResponse = fileResponse as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                throw DownloadError.badServerResponse(httpResponse.statusCode)
            }

            if fm.fileExists(atPath: localFileURL.path) {
                try fm.removeItem(at: localFileURL)
            }
            try fm.moveItem(at: tempURL, to: localFileURL)

            downloadedBytes += (entry.size ?? 0)
            let updatedFraction = Double(downloadedBytes) / Double(totalBytes)
            progressHandler(
                min(0.99, updatedFraction),
                "Saved \(fileName) (\(index + 1)/\(fileEntries.count))"
            )
        }

        progressHandler(1.0, "Download complete!")
        return destinationRoot
    }
}
