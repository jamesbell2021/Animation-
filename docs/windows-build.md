# Building the Windows version from Omarchy

Unreal can't package Windows builds on Linux, so the Windows build is made in a
Windows virtual machine. You keep developing in the Linux editor as normal; the
VM is only used to produce the `.exe`.

## One-time setup

### 1. Check virtualization is enabled (on Omarchy)

```bash
lscpu | grep -i virtualization   # should print VT-x or AMD-V
ls /dev/kvm                      # should exist
```

If not, enable **VT-x** (Intel) or **SVM** (AMD) in your BIOS.

### 2. Create the VM with quickemu

```bash
yay -S quickemu
mkdir -p ~/vms && cd ~/vms
quickget windows 11
```

Before the first boot, edit `~/vms/windows-11.conf` and add or change:

```
cpu_cores="8"      # roughly half your host's cores
ram="16G"          # 16G minimum, more is better for shader compiling
disk_size="250G"
```

Start it and let Windows install itself:

```bash
quickemu --vm windows-11.conf
```

Windows works fine unactivated for this; it just shows a watermark.

### 3. Install tools inside Windows

1. **Epic Games Launcher**, then install the **same Unreal Engine version** you
   use on Linux (check *Help → About Unreal Editor* on Linux).
2. **Visual Studio** with the **Game development with C++** workload. The game
   has C++ code, so this is required. Use the Visual Studio version listed on
   the "Setting Up Visual Studio" page of the Unreal docs for your engine version.
3. **Git for Windows** (includes Git LFS).

### 4. Get the project into the VM

In a terminal inside Windows:

```bat
git lfs install
git clone https://github.com/jamesbell2021/Animation- C:\Projects\Animation
```

Clone to a local folder with no spaces in the path. Don't build straight from a
shared network folder; it's slow and can fail halfway.

## Making a Windows build

Inside the VM:

```bat
cd C:\Projects\Animation
git pull
Scripts\package-windows.bat
```

The first build takes a long time (it compiles every shader); later ones are
much faster. The game ends up in `%USERPROFILE%\UnrealBuilds\<Project>\Shipping\Windows`.

Useful options:

| Option | What it does |
| --- | --- |
| `-Config Development` | Build with logs and the console enabled, for testing |
| `-CopyTo <folder>` | Copy the finished build somewhere, e.g. a folder shared with Omarchy |
| `-Clean` | Rebuild everything from scratch |
| `-EngineDir <path>` | Use a specific engine install instead of auto-detecting |

The script finds the `.uproject`, finds the engine, checks Visual Studio and
Git LFS are set up, then runs Unreal's `BuildCookRun` headless, so the VM
doesn't need a GPU.

## Everyday loop

1. Work on the game in Unreal on Omarchy.
2. `git push`.
3. In the VM: `git pull`, then `Scripts\package-windows.bat`.
4. Copy the build out and, optionally, smoke-test it on Omarchy with Proton/Wine.
   Always do a final check on real Windows before releasing.

## Troubleshooting

- **"Assets are Git LFS pointers"**: run `git lfs install` and `git lfs pull`.
  On Omarchy, make sure Git LFS is installed (`sudo pacman -S git-lfs`,
  then `git lfs install`) *before* committing assets.
- **"Engine ... is not registered on this machine"**: normal for projects
  created on Linux. The script picks the newest installed engine; make sure
  it's the same version you use on Linux, or pass `-EngineDir`.
- **C++ compile errors that don't happen on Linux**: MSVC is stricter than
  clang about some things (missing `#include`s, implicit conversions). Fix them
  in the source so both platforms build.
