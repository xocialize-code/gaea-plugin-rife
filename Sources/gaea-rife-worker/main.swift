import GaeaPluginKit
import RIFEPlugin

// The plugin's worker: RIFEPlugin's definition over GPP (GaeaPluginKit). `--manifest <path>` writes manifest.json.
await GaeaPluginMain.run(rifePlugin)
