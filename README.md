# mocktail-overlay

Third-party, **unofficial** Portage overlay with ebuilds for
[Mocktail](https://github.com/komaruworld/mocktail), the compatibility runtime that runs the
Android Roblox client on Linux.

This overlay is not affiliated with or endorsed by the Mocktail project, the Roblox
Corporation or VinegarHQ. I maintain **the ebuilds**, not the software. A packaging problem
is a problem for this repository — do not open an issue upstream over one.

The Roblox APK is not redistributed by any of these packages; Mocktail downloads it from a
third-party mirror on first launch.

## Packages

| Package | What it is |
|---|---|
| `app-emulation/mocktail-1.0.5` | Source build from the `1.0.5` tag. This is the one you want. |
| `app-emulation/mocktail-9999` | Live ebuild, follows `main` via `git-r3`, or upstream's experimental `vr` branch with `USE=vr` (see [VR](#vr)). |
| `app-emulation/mocktail-bin-1.0.5` | Prebuilt binary from the upstream release (linked on Arch), installed into `/opt/mocktail`. Fallback. |

`mocktail` and `mocktail-bin` block each other: install one or the other.

The packages are keyworded for `amd64` only. The runtime loads Android shared objects of the
host's own architecture, and since `1.0.5` upstream also builds for `arm64` (it then runs the
Android `arm64-v8a` client), but this overlay has not tested it: `mocktail` is plain `~amd64`.
`mocktail-bin` is `-* ~amd64`, since the upstream package it repackages is x86-64.

## Installing the overlay

The packaging lives on the orphan `gentoo-overlay` branch of this repository.
The default branch is a mirror of upstream Mocktail and carries no ebuilds, so
the branch has to be named explicitly either way.

### Clone it yourself

```sh
git clone -b gentoo-overlay --single-branch \
  https://github.com/nunreasonable/mocktail-gentoo-overlay.git \
  /var/db/repos/mocktail-overlay
```

```ini
# /etc/portage/repos.conf/mocktail-overlay.conf
[mocktail-overlay]
location = /var/db/repos/mocktail-overlay
masters = gentoo
auto-sync = false
```

Update it with `git -C /var/db/repos/mocktail-overlay pull`.

### Or let Portage manage it

```ini
# /etc/portage/repos.conf/mocktail-overlay.conf
[mocktail-overlay]
location = /var/db/repos/mocktail-overlay
masters = gentoo
auto-sync = yes
sync-type = git
sync-uri = https://github.com/nunreasonable/mocktail-gentoo-overlay.git
sync-git-clone-extra-opts = --branch gentoo-overlay
```

Then `emaint sync -r mocktail-overlay`. Portage has no `sync-branch` setting and
its git module clones whatever the default branch is, so
`sync-git-clone-extra-opts` is what pins the orphan branch; without that line
Portage clones upstream Mocktail into the repository directory and then rejects
it as invalid. Later syncs follow the branch the working tree already tracks, so
the option only matters for the first clone.

### Keywords

The ebuilds are `~amd64`:

```
# /etc/portage/package.accept_keywords/mocktail
app-emulation/mocktail     ~amd64
app-emulation/mocktail-bin ~amd64
```

## USE flags required on the dependencies

Mocktail's CMake requires `minizip.pc` (which on Gentoo only comes from `USE=minizip` on zlib)
and `webkitgtk-6.0`, whose `REQUIRED_USE` is `any-of ( aqua wayland X )`:

```
# /etc/portage/package.use/mocktail
sys-libs/zlib               minizip
media-libs/libsdl3          vulkan opengl wayland pipewire
net-libs/webkit-gtk:6       wayland
media-libs/harfbuzz         icu
media-libs/gst-plugins-base opengl
```

The last two lines are required by `webkit-gtk:6`'s own dependencies, not by Mocktail. On a
desktop profile with a global `wayland`, usually only the `zlib` and `libsdl3` lines are
needed.

`libsdl3` needs at least one audio backend, and the `default/linux/amd64/23.0` profile
enables none of them. With none compiled in, `SDL_InitSubSystem(SDL_INIT_AUDIO)` fails with
"No available audio device", which Mocktail treats as fatal — on launch and also inside the
canary that validates a freshly downloaded payload, so the failure surfaces as "could not
update or verify the Roblox installation". `app-emulation/mocktail` therefore requires one
of `pipewire`, `pulseaudio`, `alsa`, `jack` or `sndio`; pick the one matching your sound
server. `pipewire` is what the example above assumes.

## Installing

```sh
emerge -av app-emulation/mocktail
```

Be warned: it pulls in `net-libs/webkit-gtk:6`, which is a long build.

## VR

Upstream develops VR support on a separate `vr` branch, not on `main`, so only the live
ebuild offers it: `USE=vr` on `app-emulation/mocktail-9999` makes `git-r3` check out `vr`
instead of `main`. That branch last merged `main` on 2026-11-09, after `1.0.5`, and can fall
behind it between merges.

The ebuild links it against the system OpenXR loader, `media-libs/openxr-loader`, instead of
building the `third_party/OpenXR-SDK` submodule. That package lives in
[GURU](https://wiki.gentoo.org/wiki/Project:GURU), not in `::gentoo`, so GURU has to be
enabled:

```
# /etc/portage/package.accept_keywords/mocktail
=app-emulation/mocktail-9999 **
media-libs/openxr-loader ~amd64

# /etc/portage/package.use/mocktail
app-emulation/mocktail vr
```

A VR build starts in VR by default. Start WiVRn, or SteamVR with ALVR, and connect the
headset before launching `mocktail`; pass `--no-vr` to play on the desktop.

## How the ebuilds diverge from upstream

One change as a versioned patch in `files/`, not as an inline `sed`, plus a second for
`USE=vr`:

- **`mocktail-system-vulkan-headers.patch`** — `third_party/Vulkan-Headers` is a git submodule
  and comes up empty in the tarball. The `add_subdirectory()` is replaced with
  `find_package(VulkanHeaders CONFIG REQUIRED)`, using `dev-util/vulkan-headers`, which exports
  the same `Vulkan::Headers` target.
- **`mocktail-vr-system-openxr.patch`** (`USE=vr` only) — the `vr` branch builds its pinned
  `third_party/OpenXR-SDK` submodule as a static loader. The patch replaces that with
  `find_package(OpenXR CONFIG REQUIRED)`, whose `OpenXR::openxr_loader` target comes from
  `media-libs/openxr-loader`.

Beyond that, `src_configure` calls `filter-lto`. `src/compat/bionic_abi_exports.cc`
deliberately redefines glibc's `__*_chk` functions, and without `-fno-lto -fno-builtin` GCC
may fold such a call back into the wrapper itself and turn it into infinite recursion.
Upstream guards that one translation unit, but `bionic_stdio_runtime.cc`, `libc_shim.cc` and
the vendored bionic linker interpose glibc symbols the same way and are not guarded, so the
filter covers them. It also turns off the FreeBSD socket helper
(`MOCKTAIL_BUILD_FREEBSD_SOCKET_HELPER=OFF`, which only serves the Linuxulator and would drag
in `llvm-core/lld`), turns off `BUILD_TESTING` (which would `FetchContent` googletest over the
network) and does **not** pass `-DCMAKE_INSTALL_LIBDIR=lib` the way the Arch PKGBUILD does — on
Gentoo that would put 64-bit ELF objects in `/usr/lib`, a QA failure under
`FEATURES=multilib-strict`.

## License

The ebuilds are GPL-2, as is customary in Portage. Mocktail itself is Apache-2.0, with
`third_party/` bringing in BSD (ANGLE, bionic/ARM), MIT (mcpelauncher-linker) and
GPL-2-with-classpath-exception (OpenJDK JNI headers) — hence the `LICENSE` field in the
ebuilds.
