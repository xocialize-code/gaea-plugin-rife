import Foundation
import GaeaPluginKit
import GaeaProtocol
import MLXRIFE
import MLXToolKit

// gaea-plugin-rife: hzwer's Practical-RIFE 4.25 (MIT; the MLX port, mlx-rife-swift, is MIT) on MES Video 0.1's
// video.interpolate (media-engine-spec v0.9.0, Gaea AB-T-0402). One model: frames made between a clip's, so its rate rises
// by an integer factor (Video §3.5):
//
// - factor 2 to 8: (N − 1) × factor + 1 frames at the source's rate × factor, every source frame kept. Gaea turns a
//   request's `fps` into the nearest factor before the worker sees it, and puts the source's sound and markings back
//   (the package writes the picture alone).
// - Frames above 1080p are worked in 1024-pixel tiles, so a 4K clip fits the same memory as 1080p.
// - No seed: the model is deterministic. Output is an HEVC MP4, BT.709-tagged.

public let modelID = "rife-4.25"
public let maxFactor = 8
/// What the package's tiling has been measured on (BRIDGE-VID-003: 3840×2160 in 3.0 GB).
public let maxWidth = 3840, maxHeight = 2160
/// The longest clip an offer takes. RIFE works frame by frame, so this bounds the run's time, not its memory.
public let maxSourceSeconds = 300.0

/// What an interpolate job asks of the package, validated: the factor Gaea settled on.
public func factor(_ job: Job) throws -> Int {
    let factor = job.param("factor")?.intValue ?? 2
    guard (2...maxFactor).contains(factor) else {
        throw GPPError(.invalidRequest, "RIFE interpolates by a factor of 2 to \(maxFactor).", detail: ["param": "factor"])
    }
    return factor
}

/// The engine request for a clip.
public func request(video: Data, factor: Int) -> FrameInterpolateRequest {
    FrameInterpolateRequest(video: Video(format: .mp4, data: video), factor: factor)
}

let interpolateOperation = EngineOperation("video.interpolate") { job, session in
    guard let source = job.input("video") else {
        throw GPPError(.invalidRequest, "video.interpolate needs the video.", detail: ["param": "video"])
    }
    let factor = try factor(job)
    guard let response = try await session.run(request(video: try Data(contentsOf: source), factor: factor)) as? FrameInterpolateResponse else {
        throw GPPError(.modelError, "RIFE returned no video.")
    }
    let url = session.outputDir.appending(path: "video-0.mp4")
    try response.video.data.write(to: url)
    return RunResult(outputs: [.file("video", url, mediaType: "video/mp4")],
                     effective: ["factor": .int(Int64(response.appliedFactor))])
}

// MARK: - The plugin

public func lanes() -> [LaneDefinition] {
    [LaneDefinition(id: "fp32", default: true, configuration: RIFEConfiguration())]
}

let interpolateModel = ModelDefinition.engine(RIFEInterpolatePackage.self, id: modelID, title: "RIFE 4.25", lanes: lanes(),
                                              operations: [interpolateOperation])

let interpolateOffer = PluginManifest.Offer(
    operation: "video.interpolate", profile: "video",
    model: [
        "id": .string(modelID), "title": "RIFE 4.25",
        "license": ["spdx": "MIT", "commercial_use": true, "terms_url": "https://github.com/hzwer/Practical-RIFE"],
        "memory_class": "small", "speed_class": "fast", "quality_tiers": ["standard"],
        "notes": "Raises a clip's frame rate by 2 to 8 times with frames made between its own, which are all kept. Up to 4K and 5 minutes. The source's sound and markings carry over.",
        "supports": ["seed": false, "deterministic": true],
        "limits": ["max_factor": .int(Int64(maxFactor)), "max_fps": 240, "max_source_s": .double(maxSourceSeconds),
                   "max_width": .int(Int64(maxWidth)), "max_height": .int(Int64(maxHeight))],
    ])

public let rifePlugin = GaeaPluginDefinition(
    id: "com.xocialize.gaea.rife", version: "0.1.0", minGaea: "0.10.0", team: "CFZS6RXUCP",
    repo: "https://github.com/xocialize-code/gaea-plugin-rife", title: "RIFE",
    summary: "RIFE 4.25: frame interpolation (MES video.interpolate), 2 to 8 times the frame rate, every source frame kept, up to 4K.",
    license: "Apache-2.0", executable: "gaea-rife-worker",
    models: [interpolateModel], offers: [interpolateOffer])
