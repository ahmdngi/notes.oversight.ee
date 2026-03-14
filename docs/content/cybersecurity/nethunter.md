# Complete Guide: Install Kali NetHunter on Samsung Galaxy S20 FE

**Target Device:** Samsung Galaxy S20 FE (Model: r8q)  
**Difficulty Level:** Intermediate  
**Requirements:** Unlocked Bootloader, Windows PC (for Odin), USB Cable

This guide covers the complete installation of Kali NetHunter using the WirusMOD kernel, including troubleshooting tips for Docker, APT updates, and monitor mode.

---

## Prerequisites & Downloads

Before beginning the installation, ensure your device meets the following requirements and download the necessary tools.

**Device Requirements:**    
   OEM Unlocking enabled.   
   USB Debugging enabled.   
   Samsung Galaxy S20 FE (Snapdragon/5G version recommended).   

**Required Tools:**   
   **[Odin Flash Tool](https://odindownload.com/)** (Windows only).    
   **[TWRP Recovery](https://twrp.me/samsung/samsunggalaxys20fe.html)** (Specific to your device model).

**Required Files:**     
   [`vbmeta_disabled.tar`](https://androidfilehost.com/?fid=10620683726822073923)  
   [`universal-dm-verity-forceencrypt-disabler.zip`](https://zackptg5.com/android.php#disverfe)    
   [`Nethunter_WirusMOD_r8q_v4.0.zip`](https://androidfilehost.com/?fid=4279422670115701479) (Custom Kernel)   
   [`Kali NetHunter Image`](https://www.kali.org/get-kali/#kali-mobile) (Generic ARM64 or specific build)    
   [`Nethunter_WirusMOD_Binaries.zip`](https://androidfilehost.com/?fid=17248734326145720480)      

---

## Step 1: Backup and TWRP Installation

**Warning:** This process will wipe your device data. Back up important files before proceeding.

1.  **Flash TWRP:** Launch Odin on your PC. Load the `twrp-3.7.1_12-3-r8q.img.tar` file into the AP slot. Connect your device in Download Mode and flash.
2.  **Boot to Recovery:** Immediately after the flash, reboot into recovery mode (Hold Volume Up + Bixby Button + Cable Connected).
3.  **Backup:** Inside TWRP, create a full backup of your current ROM to your SD card or PC.
4.  **Flash VBMeta:** In Odin, put your device back into Download Mode and flash the `vbmeta_disabled.tar` file using the AP slot.
5.  **Reboot:** Restart the device.
6.  **Wipe Data:** Flash TWRP again via Odin. Once in TWRP, perform a "Format Data" (Factory Reset) to decrypt the storage.
7.  **Reboot Recovery:** Restart back into TWRP.

---

## Step 2: Disable Force Encryption

To ensure the custom kernel works correctly, you must disable Android's encryption verification.

1.  In TWRP, navigate to **Install** and select the downloaded `universal-dm-verity-forceencrypt-disabler.zip`.
2.  Swipe to flash.
3.  **Reboot to Recovery** immediately to ensure changes take effect.

---

## Step 3: Install Custom Kernel & Magisk

This step installs the WirusMOD kernel required for NetHunter functionality.

1.  **Flash Kernel:** In TWRP, install `Nethunter_WirusMOD_r8q_v4.0.zip`.
2.  **Reboot & Wipe:** Reboot the device and wipe the `data` partition if prompted.
3.  **Flash Magisk:** Install the latest Magisk zip file via TWRP.
4.  **Install BusyBox:** Flash `BuiltIn-BusyBox_v1.0.7.zip` (or install via the Magisk app later).
5.  **Finalize Setup:** Reboot to System. Complete the standard Android setup. If Magisk prompts for additional installation, allow it and reboot again.

---

## Step 4: Install Kali NetHunter

Now that the kernel and root are established, install the NetHunter environment.

1.  Transfer the Kali NetHunter image (`.zip`) to your device's internal storage or SD card.
2.  Open the **Magisk App**.
3.  Navigate to **Modules** > **Install from Storage**.
4.  Select the Kali NetHunter image file.
5.  Reboot your device when the installation completes.

---

## Step 5: Manual Binary Installation (Crucial)

For full functionality (HID attacks, etc.), specific binaries must be placed manually. Extract the `Nethunter_WirusMOD_r8q_vX.X_binaries.7z` archive.

**Firmware Directories:**   
Copy the extracted firmware files to the corresponding directory based on your Android version:     
   **Android 11, 12, 13:** `/vendor/firmware_mnt/image/`   
   **Android 10:** `/vendor/etc/firmware_mnt/image/`   

**Permissions:**    
   Set permissions for every copied file to `rw-r--r--` (644).

**HID Keyboard Binary:**    
   Copy the `hid-keyboard` binary to `system/xbin/`.    
   Set permissions to `rwxr-xr-x` (755).    

---

## Optional: Running Docker on NetHunter

You can run Docker containers directly on your S20 FE for portable server solutions. Execute these commands inside the **Termux** app.

**1. Install Dependencies:**
```bash
pkg install root-repo
pkg install golang make cmake ndk-multilib tsu tmux docker
```

**2. Build and Install Tini (Container Init):**
```bash
mkdir $TMPDIR/docker-build
cd $TMPDIR/docker-build
wget https://github.com/krallin/tini/archive/v0.19.0.tar.gz
tar xf v0.19.0.tar.gz
cd tini-0.19.0
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX ..
make -j8
make install
ln -s $PREFIX/bin/tini-static $PREFIX/bin/docker-init
```

**3. Running Docker:**
Start the daemon:
```bash
sudo dockerd --iptables=false
```

Test the installation:
```bash
sudo docker run hello-world
sudo docker run --network host --name nginx nginx:latest
```
*Note: Access Nginx via your phone's IP address on port 80.*

**4. Enable Internet in Containers:**
Replace `<Gateway>` with your local gateway IP (found via `ip route`):
```bash
sudo ip route add default via <Gateway> dev wlan0
sudo ip rule add from all lookup main pref 30000
```

---

## Troubleshooting & Known Bugs

### Fix: APT Update Issues
If `apt update` fails inside the NetHunter chroot, run the following commands:
```bash
echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/01-android-nosandbox
groupadd -g 3003 aid_inet && usermod -G nogroup -g aid_inet _apt
```
*Alternative solution:* Modify `/etc/passwd` and change the UID of the `_apt` user to `0`.

### Fix: Ping Permission Denied
Fix socket permissions by running:
```bash
usermod -aG sockets root
```

### Known Issues List
*   **SafetyNet:** Installing SafetyNet Fix may cause the device to freeze at the Samsung logo.
*   **USB Arsenal:** If HID functions fail, try setting them without ADB enabled.
*   **Monitor Mode:** 
    *   `airodump-ng` cannot auto-hop channels on `wlan0`.
    *   If Monitor Mode fails, enable Wi-Fi briefly, disable it, then enable Monitor Mode via the NetHunter app.
    *   **Manual Channel Setting:** Use `iwpriv wlan0 setMonChan 36 2` (for channel 36).
*   **Docker Port Forwarding:** Port forwarding (`-p`) does not work reliably. Use `--network host` mode instead.

---

## Debloat Your Device  
Improve performance and battery life by removing bloatware using these tools:      
   **[Magisk Module: Systemless Debloater](https://magiskmodule.gitlab.io/magisk-modules-repo/systemless-debloater/)**     
   **[GUI App: Debloater (F-Droid)](https://f-droid.org/packages/com.sunilpaulmathew.debloater/)**     

---

## References & Credits
*   [Official Kali NetHunter Installation Guide](https://www.kali.org/docs/nethunter/installing-nethunter/)
*   [XDA Developers: NetHunter for Galaxy S20 FE 5G r8q](https://xdaforums.com/t/kernel-nethunter-for-galaxy-s20-fe-5g-r8q-snapdragon.4205881/)
*   [Kali NetHunter Pre-created Images](https://nethunter.kali.org/images.html)