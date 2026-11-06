# Offline Image Generator — Requirements

## 1. Overview & System Requirements

### Hardware Requirements
- **Architecture**: Apple Silicon (`arm64` — M1, M2, M3, M4, or newer series processors).
- **Memory (Unified RAM)**:
  - **Minimum**: 8 GB Unified Memory (using 6-bit palettized CoreML models or with *Reduce Memory Mode* enabled).
  - **Recommended**: 16 GB+ Unified Memory (for full `Float16` Stable Diffusion 1.5 / 2.1 or Stable Diffusion XL models).
- **Disk Space**:
  - Application binary: ~25 MB.
  - Offline CoreML Model Packages: ~1.0 GB to 2.5 GB per model (stored locally).

### Operating System & Toolchain Requirements
- **Operating System**: macOS 14.0 (Sonoma) or later.
- **Swift Toolchain**: Swift 5.10+ / Swift 6.x (Xcode 15.4+ or Command Line Tools for Xcode).
- **System Frameworks Used**:
  - `SwiftUI` & `AppKit` (Native macOS user interface, file/save panels, clipboard integration)
  - `CoreML` (Hardware-accelerated Neural Engine and Metal GPU model execution)
  - `Accelerate` & `CoreGraphics` (vImage latent decoding and bitmap rendering)
  - `NaturalLanguage` (Tokenization and multilingual embeddings)
  - `UniformTypeIdentifiers` (PNG/JPEG export content types)

---

## 2. Swift Package Dependencies

Dependencies are managed declaratively via Swift Package Manager in [`Package.swift`](Package.swift):

| Package | Repository | Minimum Version | Purpose |
| :--- | :--- | :--- | :--- |
| **ml-stable-diffusion** (`StableDiffusion`) | `https://github.com/apple/ml-stable-diffusion.git` | `1.1.1` | Apple's official CoreML Stable Diffusion & SDXL inference pipeline for Apple Silicon |

---

## 3. Offline AI Model Requirements

The application runs inference **100% offline** using compiled CoreML Stable Diffusion bundles (`.mlmodelc`). A valid model directory must contain:

- `Unet.mlmodelc` (or `UnetChunk1.mlmodelc` + `UnetChunk2.mlmodelc`)
- `VAEDecoder.mlmodelc`
- `TextEncoder.mlmodelc` (and `TextEncoder2.mlmodelc` for SDXL models)
- `vocab.json`
- `merges.txt`
- *(Optional)* `SafetyChecker.mlmodelc`
- *(Optional)* `VAEEncoder.mlmodelc`

### Optional Python Environment (Only for Custom Model Conversion)
If you wish to convert your own PyTorch/Diffusers checkpoints (`.safetensors` or Hugging Face models) into `.mlmodelc` bundles offline, you can use Apple's Python conversion package:

```txt
coremltools>=7.0
torch>=2.0.0
diffusers[torch]>=0.24.0
transformers>=4.35.0
accelerate>=0.24.0
huggingface-hub>=0.19.0
scipy>=1.11.0
```
*(Note: Python is **not** required to build or run the native Swift macOS application; you can download pre-compiled Apple CoreML models directly from within the app or load any local folder).*

---

## 4. Functional Requirements Implemented

1. **Native Apple Silicon macOS Application**: Built in pure Swift & SwiftUI targeting `arm64-apple-macosx`.
2. **Offline AI Model Display & Selector Component (`OfflineModelCardView`)**:
   - Displays the currently loaded offline AI model name, detected architecture (`Stable Diffusion 1.5/2.1` or `SDXL`), disk size, folder path, and individual `.mlmodelc` components.
   - Allows selecting any local folder on disk (`NSOpenPanel`) or downloading Apple's official CoreML models from Hugging Face into `~/Library/Application Support/OfflineImageGenerator/Models`.
   - Allows configuring Apple Silicon Compute Units (`CPU + Neural Engine`, `CPU + GPU (Metal)`, `All`, `CPU Only`) and `Reduce Memory Mode`.
3. **Prompt Input Component (`PromptInputPanelView`)**:
   - Multi-line text editor for the positive prompt, plus sample prompt ideas.
   - Optional negative prompt text box.
   - Configurable inference steps, guidance scale (CFG), scheduler (`DPM-Solver++` or `PNDM`), seed control, and live intermediate preview toggle.
4. **Generated Image Preview Component (`ImagePreviewPanelView`)**:
   - High-resolution scalable preview of the generated image, including optional live denoising step previews and a real-time progress indicator.
   - Displays generation telemetry (image dimensions, seed used, inference time in seconds, and active offline model).
5. **Download / Export Button**:
   - Native macOS Save Panel (`NSSavePanel`) via the **Download Image** button (`⌘S`) to save generated images as `.png` or `.jpg` files, plus a quick **Copy** to clipboard button.
