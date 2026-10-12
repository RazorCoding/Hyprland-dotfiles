# Steam / NVIDIA GPU setup on Hyprland (hybrid AMD + NVIDIA)

Lenovo w/ **AMD Vega iGPU** (drives the display) + **GTX 1650 dGPU** (3D only),
Hyprland + Wayland, config is `~/.config/hypr/hyprland.lua` (Lua).

## Current intended setup (final)

- **Desktop / Hyprland / non-Steam apps** → AMD iGPU (session env).
- **Steam client + every game** → NVIDIA dGPU (launched via PRIME offload).
  Games inherit the env, so no per-game options needed.

This is the "best of both": light desktop on the efficient iGPU, games on the
fast dGPU, and GPU selection is explicit and stable.

## Config — `~/.config/hypr/hyprland.lua`

1. Session defaults → AMD iGPU (everything not offloaded):
   ```lua
   hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
   hl.env("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/50_mesa.json")
   hl.env("VK_LOADER_DRIVERS_DISABLE", "nvidia_icd.json")
   hl.env("LIBVA_DRIVER_NAME", "radeonsi")
   ```
2. Launch Steam on the dGPU (autostart **and** `Super+X`):
   ```lua
   hl.exec_cmd("env -u VK_LOADER_DRIVERS_DISABLE prime-run steam")
   hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("env -u VK_LOADER_DRIVERS_DISABLE prime-run steam"))
   ```

## Why each piece exists

- `prime-run` → sets `__NV_PRIME_RENDER_OFFLOAD=1`, `__VK_LAYER_NV_optimus=NVIDIA_only`,
  `__GLX_VENDOR_LIBRARY_NAME=nvidia`: forces the process tree onto the dGPU.
- `env -u VK_LOADER_DRIVERS_DISABLE` → **required** because the session block
  above would otherwise keep the NVIDIA Vulkan driver disabled, and Vulkan games
  (CS2, most Proton titles) would silently stay on the iGPU despite `prime-run`.
- The session `hl.env(...)` block keeps the compositor and every other app on the
  iGPU. Note Steam's runtime may override `VK_ICD_FILENAMES`, but it does not
  touch `VK_LOADER_DRIVERS_DISABLE` — that's the reliable filter.

Apply with `hyprctl reload`, then restart Steam. (`reload` re-sets declared env
vars but never unsets removed ones, so a running Steam stays stale.)

## Verify

```sh
cat /proc/$(pgrep -x steam | head -1)/environ | tr '\0' '\n' | grep -E 'GLX|EGL|VK_|LIBVA|PRIME'
# expect: __NV_PRIME_RENDER_OFFLOAD=1, __VK_LAYER_NV_optimus=NVIDIA_only,
#         __GLX_VENDOR_LIBRARY_NAME=nvidia, VK_LOADER_DRIVERS_DISABLE GONE
nvidia-smi        # steam + steamwebhelper present = expected/intended now
```

## History / why it was confusing

1. Original config: session forced `nvidia` **and** an *unintentional*
   `prime-run steam` autostart → Steam on the dGPU "no matter what" and repeated
   on every login (the "again and again" bug).
2. Intermediate: everything forced to the iGPU (clean `nvidia-smi`) → games then
   ran on the weak Vega → stutter/low FPS.
3. **Final (this doc):** desktop on iGPU, Steam + games deliberately offloaded to
   the dGPU.

## Notes & caveats

- `nvidia-smi` showing Steam processes is **expected** again (intentional
  offload), unlike step 2 where it was the symptom of the bug.
- **dGPU idle power:** it never suspends (`power/control = on`) → ~5.6 W / ~58 °C
  idle. An RTD3 udev rule could suspend it, **but while Steam runs on the dGPU it
  will keep it awake anyway** — sleep is only useful if you quit Steam.
- **Per-game → iGPU**, override the inherited offload in that game's launch
  options:
  ```
  env __NV_PRIME_RENDER_OFFLOAD=0 __GLX_VENDOR_LIBRARY_NAME=mesa VK_LOADER_DRIVERS_DISABLE=nvidia_icd.json %command%
  ```
- Stale terminals (spawned before a reload) still carry old env — open a new one
  after any change before judging.