# Steam on the AMD iGPU (hybrid AMD + NVIDIA, Hyprland/Wayland)

Goal: run Steam (client + games) on the **AMD iGPU**, never the GTX 1650, and keep
`nvidia-smi` clean.

## Root cause (why it kept "coming back")

Two separate things forced Steam onto the dGPU:

1. **Session-wide Nvidia env vars** in `~/.config/hypr/hyprland.lua`, which forced
   *everything* (GLX/EGL/VA-API) onto Nvidia:
   ```lua
   hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
   hl.env("LIBVA_DRIVER_NAME", "nvidia")
   ```
2. **Steam was launched with `prime-run`** — `prime-run` exports
   `__NV_PRIME_RENDER_OFFLOAD=1`, `__VK_LAYER_NV_optimus=NVIDIA_only` and
   `__GLX_VENDOR_LIBRARY_NAME=nvidia`, which **override** any global setting for
   that process tree. It was in the config twice:
   ```lua
   hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("prime-run steam"))  -- Super+X
   hl.exec_cmd("prime-run steam")                                  -- autostart at login
   ```
   Because it was an **autostart**, Steam re-appeared on the dGPU on every login —
   hence "again and again".

## The fix — `~/.config/hypr/hyprland.lua`

1. Point the whole session at the AMD iGPU:
   ```lua
   hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
   hl.env("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/50_mesa.json")
   hl.env("VK_LOADER_DRIVERS_DISABLE", "nvidia_icd.json")   -- key: survives Steam Runtime
   hl.env("LIBVA_DRIVER_NAME", "radeonsi")
   ```
2. Stop launching Steam through `prime-run`:
   ```lua
   hl.exec_cmd("steam")        -- was: hl.exec_cmd("prime-run steam")
   ```

`VK_LOADER_DRIVERS_DISABLE` is the important, non-obvious one: Steam's Runtime
**overwrites** `VK_ICD_FILENAMES` to re-add the Nvidia Vulkan ICD, but it does not
touch the Vulkan loader's disable list, so this is what keeps CEF/Chromium
(`steamwebhelper`) off the dGPU.

Apply with `hyprctl reload`, then restart Steam (reload re-sets declared env vars
but never *unsets* removed ones, so a running Steam/compositor stays stale).

## Verify

```sh
nvidia-smi                       # -> "No running processes found"
prime-run --help >/dev/null      # (sanity)
cat /proc/$(pgrep -x steam | head -1)/environ | tr '\0' '\n' | grep -E 'GLX|EGL|VK_|LIBVA|PRIME'
# expect mesa / radeonsi / VK_LOADER_DRIVERS_DISABLE, and NO __NV_PRIME_RENDER_OFFLOAD
```

Confirmed: all `steamwebhelper` processes have zero Nvidia libs mapped and
`nvidia-smi` shows no processes.

## Caveats

- **Stale terminals:** a terminal opened *before* the reload still carries the old
  env. Open a new one, or log out/in, before judging. Launching `steam` from a
  stale shell will put it back on Nvidia.
- **`prime-run` is disabled for Vulkan** while `VK_LOADER_DRIVERS_DISABLE` is set.
  To offload one specific title to the dGPU anyway, use Steam launch options:
  `env -u VK_LOADER_DRIVERS_DISABLE prime-run %command%`.
- **`Super+X` still runs `prime-run steam`.** Since Steam is single-instance, this
  only focuses a running Steam; it won't move an already-running instance to the
  dGPU. Change it to `steam` if Nvidia should never be used.
- Steam's embedded browser (CEF) may still *enumerate* GPUs; the concern is only
  actual contexts, which are what show up in `nvidia-smi`.

## Optional: let the idle dGPU sleep (~5.6 W / 58 C idle)

The dGPU stays powered because `power/control = on` (runtime PM disabled), even
though RTD3 is enabled (`NVreg_DynamicPowerManagement=3`). No udev rule sets it to
`auto`. Create `/etc/udev/rules.d/80-nvidia-pm.rules`:

```
ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
```

Or test at runtime: `echo auto | sudo tee /sys/bus/pci/devices/0000:01:00.0/power/control`
(should flip `runtime_status` to `suspended` when idle). Revert to `on` if
`prime-run` misbehaves.
