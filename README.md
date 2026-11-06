# OfflineImageGenerator (macOS Apple Silicon)

A native macOS application written in **Swift** and **SwiftUI** for **Apple Silicon (`arm64`)** that generates images **100% locally and offline** using Apple's **CoreML Stable Diffusion** (`ml-stable-diffusion`) engine.

All inference runs directly on your Mac's **Apple Neural Engine (ANE)** and **Metal GPU**—no cloud APIs, no subscriptions, and no internet connection required after a model is on disk.

---

## Key Features & UI Components

1. **Offline AI Model Inspector & Selector (`OfflineModelCardView`)**
   - Displays the currently loaded offline AI model name, detected architecture (`Stable Diffusion 1.5/2.1` or `Stable Diffusion XL`), total disk footprint, local folder path, and individual `.mlmodelc` bundles (`Unet.mlmodelc`, `VAEDecoder.mlmodelc`, `TextEncoder.mlmodelc`, `vocab.json`, `merges.txt`).
   - **Load Folder...**: Browse and load any local directory containing compiled CoreML Stable Diffusion bundles.
   - **Download Model...**: Built-in downloader for Apple's official pre-compiled CoreML models on Hugging Face (e.g., `apple/coreml-stable-diffusion-v1-5-palettized`), saving them directly to `~/Library/Application Support/OfflineImageGenerator/Models`.
   - **Apple Silicon Hardware Controls**: Switch between `CPU + Neural Engine`, `CPU + GPU (Metal)`, `All`, or `CPU Only`, and toggle `Reduce Memory Mode` for 8 GB Macs.

2. **Prompt Input Box & Generation Controls (`PromptInputPanelView`)**
   - Multi-line positive prompt editor with quick sample prompt ideas.
   - Optional negative prompt text box to exclude unwanted visual artifacts.
   - Adjustable **Inference Steps** (`10–50`), **Guidance Scale / CFG** (`1.0–15.0`), **Scheduler** (`DPM-Solver++` or `PNDM`), **Seed** (random or fixed), and **Live Step Preview**.

3. **Generated Image Preview & Download Button (`ImagePreviewPanelView`)**
   - High-resolution scalable canvas displaying live intermediate denoising steps and the final generated image.
   - Progress bar with step-by-step status telemetry, output dimensions, seed used, and generation duration.
   - **Download Image (`⌘S`)**: Native macOS save dialog (`NSSavePanel`) to export the generated image as **PNG** or **JPEG**, alongside a one-click **Copy** to clipboard button.

---

## Project Structure

```text
offline-image-generator/
├── Package.swift
├── README.md
├── REQUIREMENTS.md
└── Sources/
    └── OfflineImageGenerator/
        ├── OfflineImageGeneratorApp.swift       # Native macOS App entry point & window config
        ├── Models/
        │   └── AIModelMetadata.swift            # Compute units, schedulers, model info & presets
        ├── Services/
        │   ├── ModelDirectoryInspector.swift    # Validates local .mlmodelc directories
        │   ├── HuggingFaceModelDownloader.swift # Downloads Apple CoreML models for offline use
        │   └── StableDiffusionService.swift     # CoreML StableDiffusion & SDXL pipeline actor/service
        ├── ViewModels/
        │   └── ImageGeneratorViewModel.swift    # MainActor observable state & export logic
        └── Views/
            ├── ContentView.swift                # Main split-view layout
            ├── OfflineModelCardView.swift       # Offline AI model display, selector & downloader UI
            ├── PromptInputPanelView.swift       # Prompt text box & diffusion parameter controls
            └── ImagePreviewPanelView.swift      # Image preview canvas & Download button
```

---

## Getting Started

### 1. Prerequisites
- **Mac with Apple Silicon** (M1 / M2 / M3 / M4 or newer)
- **macOS 14.0 (Sonoma)** or newer
- **Swift 5.10+** / **Xcode 15.4+**

See [`REQUIREMENTS.md`](REQUIREMENTS.md) for full hardware, software, and model specifications.

### 2. Build and Run from Terminal

To build a complete, signed macOS `.app` bundle for **Apple Silicon (`arm64`)** including the custom cream **Image Generator** `.icns` app icon:

```bash
./scripts/build-macos-app.sh
open build/OfflineImageGenerator.app
```

Or build and run directly via Swift Package Manager:

```bash
swift build -c release --arch arm64
swift run -c release OfflineImageGenerator
```

Or open [`Package.swift`](Package.swift) directly in **Xcode**:

```bash
xed .
```
Then press **⌘R** to build and launch the native macOS app.

---

## Loading an Offline AI Model

When you launch **OfflineImageGenerator**, you have two ways to configure your offline model:

### Option A — Use the Built-in Model Downloader
1. In the left sidebar under **Offline AI Model**, click **Download Model...**.
2. Choose one of Apple's official pre-compiled CoreML models:
   - **Stable Diffusion v1.5 (6-bit Palettized)** (~1.0 GB — fast, great for 8 GB+ Macs)
   - **Stable Diffusion v2.1 Base (6-bit Palettized)** (~1.1 GB)
   - **Stable Diffusion v1.5 (Float16)** (~2.0 GB)
3. Click **Download Selected Model**. Once downloaded, the model is stored permanently in `~/Library/Application Support/OfflineImageGenerator/Models/` and works completely offline.

### Option B — Load an Existing Local Folder
1. Click **Load Folder...** in the **Offline AI Model** card.
2. Select any local directory containing compiled `.mlmodelc` bundles (`Unet.mlmodelc`, `VAEDecoder.mlmodelc`, `TextEncoder.mlmodelc`, `vocab.json`, `merges.txt`).

---

## Generating & Downloading Images

1. Verify that the **Offline AI Model** card shows your selected model (`On Disk` or `Ready Offline`).
2. Enter your description in the **Prompt** text box (and optionally a **Negative Prompt**).
3. Click **Generate Image Offline** (or press **⌘↩**).
4. Watch the real-time denoising progress in the **Generated Image Preview** panel.
5. Click **Download Image** (or press **⌘S**) in the top-right corner of the preview panel to save your image as `.png` or `.jpg`.
