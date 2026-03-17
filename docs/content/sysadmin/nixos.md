---
icon: material/nix
tags:
  - sysadmin
  - nixos
  - linux
---
# NixOS

## Performance Tuning

### Slow System Performance

After installing NixOS, the system may feel sluggish. This is often caused by the CPU governor being set to `powersave` mode by default.

#### Diagnosing the Issue

Check the current CPU governor for each core:

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

Output showing powersave mode:
```
powersave
powersave
powersave
powersave
powersave
powersave
powersave
powersave
```

#### Available Governors

Use `cpufrequtils` to check available governors:

```bash
nix-shell -p cpufrequtils
cpufreq-info | grep "governor"
```

#### Solution

Add the following to your `configuration.nix`:

```nix
powerManagement.cpuFreqGovernor = "performance";
```

After rebuilding, verify the change:

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

Output should now show:
```
performance
performance
performance
performance
performance
performance
performance
performance
```

## Known Issues

### VirtualBox Kernel Incompatibility

VirtualBox may fail to install or run on kernel 6.12 due to module compilation issues.

**Tracking Issue:** [nixpkgs#363887](https://github.com/NixOS/nixpkgs/issues/363887)

**Workaround:** Consider using an alternative virtualization solution or downgrading the kernel until the issue is resolved.

## References

- [NixOS Options: powerManagement.cpuFreqGovernor](https://search.nixos.org/options?channel=unstable&from=0&size=30&sort=relevance&type=packages&query=powerManagement.cpuFreqGovernor)
- [Reddit: NixOS Slow Performance Discussion](https://www.reddit.com/r/NixOS/comments/lcbz8x/nixos_slow/)
- [NixOS Wiki: Laptop Configuration](https://nixos.wiki/wiki/Laptop)
