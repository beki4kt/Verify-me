# Install the Chekmi iPhone test build from Windows

This native release includes the current iPhone UI, receipt camera, and ML Kit
text recognition. It requires iOS 15.5 or later and uses the configured HTTPS
staging services. The IPA is unsigned until AltStore signs it with your account.

1. Follow the [official Windows setup guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
   to install Apple's desktop iTunes/iCloud dependencies and AltServer.
2. Connect the unlocked iPhone by USB and accept the computer trust prompt.
3. Enable Wi-Fi sync for the phone in iTunes.
4. In the Windows tray, use AltServer's **Install AltStore** menu and select
   the iPhone. Enter your Apple account credentials in AltServer itself.
5. On iPhone, trust the account under **Settings > General > VPN & Device
   Management**. On iOS 16+, enable **Privacy & Security > Developer Mode**,
   restart, and confirm.
6. Put `Chekmi-iPhone.ipa` in iCloud Drive so it appears in iPhone Files.
   Alternatively, download the build artifact from GitHub on the phone and
   unzip the outer artifact ZIP in Files to access the IPA.
7. Keep AltServer running and both devices on the same network. Open AltStore,
   sign in if requested, then choose **My Apps > +** and select the IPA.
8. Open Chekmi. Use **Try the live demo > Staff > OPEN PAYMENTS > Scan**, select
   a provider, and allow the camera. Capture a receipt to test text extraction.

With a free Apple account, refresh apps within seven days using AltStore's
**Refresh All** while AltServer is reachable. See [AltStore's app management
guide](https://faq.altstore.io/altstore-classic/your-altstore).

The native app can run without this Windows PC after installation, provided
its backend services are reachable. AltServer is needed again for refreshing.
This build is for device testing; App Store release checks remain separate.

To rebuild, push an updated `build/iphone-altstore-*` branch. The
`iPhone IPA for AltStore` workflow uploads `Chekmi-iPhone-AltStore`, containing
the IPA, SHA-256 checksum, and source/build information. Artifacts expire after
seven days, so retain the downloaded IPA locally.
