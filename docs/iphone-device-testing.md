# Testing Chekmi on an iPhone without the App Store

Chekmi has two useful device-testing paths. The Windows path is available now
and reviews the iPhone UI in Safari. The native path installs the actual iOS app
directly from Xcode and requires a Mac.

## From this Windows PC: Safari device preview

This path does not upload anything and does not need an Apple account.

1. Connect the Windows PC and iPhone to the same Wi-Fi network. A normal Wi-Fi
   router is the most reliable option. An iPhone Personal Hotspot may also work,
   but some hotspot or corporate networks isolate connected devices.
2. Open **PowerShell as Administrator** once, move to the repository, and allow
   the local preview port:

   ```powershell
   Set-Location 'C:\Users\alema\Documents\GitHub\Verify-me'
   powershell.exe -NoProfile -ExecutionPolicy Bypass `
     -File .\scripts\allow_iphone_preview_firewall.ps1
   ```

3. Open a normal PowerShell window and start the visual preview:

   ```powershell
   Set-Location 'C:\Users\alema\Documents\GitHub\Verify-me'
   powershell.exe -NoProfile -ExecutionPolicy Bypass `
     -File .\scripts\start_iphone_preview.ps1
   ```

4. The script prints an address such as `http://172.20.10.2:8087`. Open that
   exact address in Safari on the iPhone and keep the PowerShell window running.
5. Stop the server with `Ctrl+C`.

The default uses an optimized release runtime so Safari performance is close to
the installable app. It is interactive: it initializes Hive device storage and can
connect to the `MESOB-DEMO` workspace using the development services. To
enable Flutter hot reload during development, add `-Development`. To exercise the
shared app flows against the configured staging services, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\start_iphone_preview.ps1 -Functional
```

Functional mode reads the uncommitted `config\staging.json`. Staging must use
HTTPS and permit the preview origin. For screenshots that must ignore any
previously stored workspace, use the intentionally non-interactive mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\start_iphone_preview.ps1 -VisualOnly
```

`-VisualOnly` skips storage startup, so workspace connection and other
data-changing actions are not supported in that mode. Native-only behavior such as camera
permission prompts, keychain storage, app lifecycle, and Apple signing cannot be
validated in Safari.

## Camera capture from Windows using HTTPS

The opt-in browser camera test uses the current iPhone UI and the rear camera
when available. Build it with:

```powershell
flutter build web --release --dart-define-from-file=config/staging.json --dart-define=CHEKMI_IPHONE_UI=true --dart-define=CHEKMI_WEB_CAMERA_TEST=true --output=build/iphone-camera-web
node scripts/serve-camera-preview.cjs
```

In a second terminal run `cloudflared tunnel --url http://127.0.0.1:8091`.
Open its printed HTTPS URL in iPhone Safari. This temporary URL is public;
the server serves only the compiled preview directory. Keep both processes
running while testing and stop them with Ctrl+C afterward.

Open the demo, choose Waiter, tap OPEN WAITER, then Scan, choose a payment
provider, and allow camera access. CAPTURE RECEIPT attaches the photo to the
ticket form. Enter the transaction reference manually: native ML Kit OCR is
not available in this browser test. Native image compression is also bypassed.
Camera permissions here are Safari permissions, not the native iOS app's.

## Native install from a Mac: no App Store upload

A free Apple Account is sufficient for testing on an iPhone that you own. Free
Personal Team provisioning expires after seven days, so the app must be built
and installed again periodically. A paid Apple Developer Program membership is
not required for this personal-device workflow.

### One-time Mac setup

1. Use a Mac that supports the current Xcode release. Install Xcode from the Mac
   App Store, launch it once, accept its license, and install the iOS platform.
2. Install the current stable Flutter SDK and run `flutter doctor -v` until the
   iOS toolchain is healthy.
3. Clone or copy this repository to the Mac and run `flutter pub get`.
4. Connect the unlocked iPhone by USB, tap **Trust** on both devices when asked,
   and enable **Developer Mode** on the iPhone under **Settings > Privacy &
   Security**. The phone restarts and asks for confirmation.
5. Open `ios/Runner.xcworkspace` in Xcode.
6. Select the **Runner** target, open **Signing & Capabilities**, leave
   **Automatically manage signing** enabled, and choose the Personal Team for
   the signed-in Apple Account.
7. Replace the provisional bundle ID `com.chekmi.app` if Xcode says it is not
   unique. A development-only value such as `com.yourname.chekmi.dev` is fine.
8. Select the connected iPhone as the run destination and press Xcode's Run
   button. The first launch can ask you to trust the developer identity.

After signing works once, the same staging build can be launched from Terminal:

```bash
flutter devices
flutter run -d DEVICE_ID --dart-define-from-file=config/staging.json
```

The iPhone presentation is selected automatically for a native iOS target. Keep
the first USB setup; Xcode can optionally pair the phone for later wireless runs
on the same network.

## What each route proves

| Check | Safari from Windows | Native from Xcode |
| --- | --- | --- |
| iPhone layout and responsive sizing | Yes | Yes |
| Shared Dart business flows | Yes, in default or `-Functional` mode | Yes |
| Camera permission and scanning | No | Yes |
| iOS lifecycle and native storage | No | Yes |
| Code signing and installability | No | Yes |
| App Store or TestFlight upload | Not involved | Not involved |
