# gaea-plugin-rife

hzwer's **Practical-RIFE 4.25** (MIT) as a [Gaea](https://github.com/xocialize-code/gaea) plugin: frame interpolation, on
MES Video 0.1's `video.interpolate`. It is built on [GaeaPluginKit](https://github.com/xocialize-code/gaea-plugin-kit) over
[mlx-rife-swift](https://github.com/xocialize/mlx-rife-swift), runs in its own process, and speaks the Gaea Plugin
Protocol v1. Add it to Gaea by its repo URL:

```bash
gaea plugins add https://github.com/xocialize-code/gaea-plugin-rife
```

## What it offers

One model, `rife-4.25`, on `video.interpolate`: frames made between a clip's, so its frame rate rises by a whole factor.

- **`factor`** 2 to 8 (the default is 2). The clip comes back with (N − 1) × factor + 1 frames at its rate × factor, and
  every source frame is kept: source frame i is output frame i × factor.
- **`fps`** instead of `factor`: Gaea uses the nearest factor and warns `fps_adjusted` when the rate differs. For
  example, 60 fps from a 24 fps clip is factor 3, which is 72 fps.
- **Sound and markings.** The package writes the picture alone. Gaea puts the source's audio track and its markings
  (comment, copyright) back, unchanged, as Video §1.7 and §1.9 ask.
- **Sizes:** up to 3840×2160. Above 1080p the package works in 1024-pixel tiles, so 4K fits the same memory as 1080p.
- **Length:** clips up to 300 s.
- **Determinism:** no seed (`supports.seed: false`, `deterministic: true`). The same clip gives the same frames.
- **Output:** an HEVC MP4. Gaea retimes it to the exact rate and gives H.264 when the request's `output.codec` asks.

On an M5 Max, a 128×96, 17-frame clip interpolates in about 0.3 s warm. The worker's footprint is about 220 MB.

## Lanes and memory

One lane, `fp32` (the 21 MB weights; 150 MB resident with overhead, up to 4 GB more while running, by the package's
measurements).

## Weights

Gaea sends its models root in `configure` (MLXEngine's store by default). The package reads
`mlx-community/RIFE-4.25` there, at `models/mlx-community/RIFE-4.25`, through its own Hugging Face client, which also
downloads it when it's missing.

## Build and check locally

```bash
scripts/build-plugin.sh
```

```bash
scripts/check-plugin.sh
```

`check-plugin.sh` interpolates `Tests/Fixtures/clip.mp4` over GPP on the signed bundle, with every `.build` folder
hidden. It then shows that the bare worker, outside the bundle, finds no metallib.

`scripts/release.sh` builds, checks, notarizes with the fleet's `mlx-notary` profile, and publishes the GitHub release.
The release workflow does the same in CI when a `v<version>` tag is pushed.

`rife-inproc` (its header lists the options) is not part of the plugin. It runs the same lane in-process through
MLXServeEngine, with the worker's request: the reference Gaea's runs are compared against.

```bash
scripts/golden.sh <out-dir>
```

`golden.sh` interpolates the fixtures over GPP on the signed bundle and through `rife-inproc`, and needs each pair to
decode to the same frames, byte for byte (ffmpeg's `framemd5`), with the right count.
- The cases: `clip.mp4` (128×96, 17 frames at 24 fps, with sound) at factors 2, 4 and 8, and `clip360.mp4` (640×360, 48
  frames) at factor 2.
- The MP4s themselves differ only in their creation time. The fixtures were made with ffmpeg's `testsrc2`.

## CI secrets

The release workflow signs with Developer ID and notarizes. It reads four organization secrets on xocialize-code:
`DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`, `NOTARY_APPLE_ID` and `NOTARY_APP_PASSWORD` (Gaea's
`Docs/Signing secrets.md`).

## Licence

The plugin is Apache-2.0 (Gaea G-21). Practical-RIFE and its weights are MIT (hzwer), and so is the port,
mlx-rife-swift.
