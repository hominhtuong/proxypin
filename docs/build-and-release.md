# Build và phát hành

Ghi lại những gì thực sự cần để build ProxyPin trên từng nền tảng, kèm các bẫy đã gặp thật. Đọc trước khi build lần đầu sẽ tiết kiệm được vài tiếng.

## Yêu cầu chung

| Thứ | Vì sao cần |
|---|---|
| Flutter 3.44.4 stable | Bản đang dùng cho repo này |
| **Rust (rustup + cargo)** | `code_forge` là FFI plugin viết bằng Rust. Cargokit build nó lúc compile và **không tự cài Rust** - thiếu là build chết ở mọi nền tảng |

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
export PATH="$HOME/.cargo/bin:$PATH"     # thêm vào ~/.zshrc cho tiện
```

## macOS

### Bẫy 1: Swift Package Manager làm app đen màn hình

Flutter 3.44 bật SPM mặc định. `podhelper.rb` bỏ qua mọi plugin có `Package.swift`, mà `Package.swift` của `code_forge` **không có bước build Rust** - bước đó chỉ nằm trong `code_forge.podspec` (`script_phase` gọi cargokit).

Hậu quả: `libcode_forge.a` không được tạo, `RustLib.init()` ở `main.dart:42` ném exception, `main()` chết trước khi dựng UI, cửa sổ hiện ra trống trơn màu đen.

```sh
flutter config --no-enable-swift-package-manager
flutter clean && rm -rf macos/Pods macos/Podfile.lock
flutter build macos --release
```

Cách nhận biết đã dính: `grep code_forge macos/Podfile.lock` không ra gì.

### Bẫy 2: `zstandard_macos` tự xoá source giữa các lần build

Pod này có `script_phase` tên `Remove synced zstd` chạy `rm -rf Classes/zstd` ở cuối mỗi build, và `Sync zstd` sinh lại ở đầu build sau. Hai bước đua nhau nên thỉnh thoảng báo:

```
error: Build input file cannot be found: '.../zstd/decompress/huf_decompress_amd64.S'
```

Chạy `flutter build` lần nữa là qua. Không phải lỗi code.

### Ký và notarize để phát cho người khác

Ký thôi **chưa đủ** - từ macOS 10.15 Gatekeeper vẫn chặn nếu chưa notarize. Cần đúng hai thứ:

1. Certificate **Developer ID Application** (khác **Developer ID Installer**, cái sau chỉ ký `.pkg`)
   `Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application`
2. Credential notary lưu vào Keychain:
   ```sh
   xcrun notarytool store-credentials proxypin-notary \
     --apple-id <email> --team-id <TEAM_ID> --password <app-specific-password>
   ```
   App-specific password lấy ở appleid.apple.com > Sign-In and Security.

Rồi chạy:

```sh
bash scripts/sign_notarize_macos.sh
```

Script tự dò cert, ký từ trong ra ngoài (framework trước, app sau), bật hardened runtime, gửi notarize, staple vé, đóng gói DMG rồi ký + notarize luôn cả file DMG.

Kiểm chứng đúng cách - phải gắn cờ quarantine để mô phỏng file tải từ mạng:

```sh
cp ProxyPin.dmg /tmp/t.dmg
xattr -w com.apple.quarantine "0083;00000000;Safari;" /tmp/t.dmg
MP=$(hdiutil attach /tmp/t.dmg -nobrowse -readonly | tail -1 | awk -F'\t' '{print $NF}')
spctl -a -t exec -vv "$MP/ProxyPin.app"     # phai ra: accepted / Notarized Developer ID
```

Chỉ chạy `spctl` trên file chưa quarantine sẽ cho kết quả sai lệch.

### Bẫy 3: entitlements có key trùng

`macos/Runner/Release.entitlements` (bản upstream) khai `com.apple.security.files.user-selected.read-write` **hai lần**. Xcode bỏ qua được nên không ai để ý, nhưng `codesign --entitlements` từ chối:

```
Failed to parse entitlements: AMFIUnserializeXML: duplicate dictionary key near line 16
```

Đã sửa trong fork này. Kiểm tra bằng `plutil -lint macos/Runner/Release.entitlements`.

## Android

### Bắt buộc có `android/key.properties`

`android/app/build.gradle` gán `signingConfig signingConfigs.release` cho **cả** `release` lẫn `debug`. Thiếu file này thì mọi APK đều fail:

```
SigningConfig "release" is missing required property "storeFile".
```

Dùng debug keystore cho bản cài nội bộ:

```
storePassword=android
keyPassword=android
keyAlias=androiddebugkey
storeFile=/Users/<ten>/.android/debug.keystore
```

File này **không được commit** - đã nằm trong `.git/info/exclude`.

### Không dùng được `--split-per-abi`

`android/build.gradle` đã tự khai `abiFilters`, xung đột với splits:

```
Conflicting configuration : 'armeabi-v7a,arm64-v8a,x86_64' in ndk abiFilters
cannot be present when splits abi filters are set
```

Build APK universal: `flutter build apk --release`.

### NDK tải dở dang

Nếu gặp:

```
[CXX1101] NDK at .../ndk/<ver> did not have a source.properties file
```

Thư mục NDK chỉ có `.installer`, tức bản tải bị đứt. Xoá rồi cài lại:

```sh
rm -rf ~/Library/Android/sdk/ndk/<ver>
~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager --install "ndk;<ver>"
```

## iOS

Cần provisioning profile cho **cả hai** bundle, vì app có network extension:

- `com.dt.proxypin` - app chính
- `com.dt.proxypin.ProxyPin` - extension VPN
- app group `group.com.dt.proxypin` dùng chung giữa hai bên

```sh
flutter build ipa --release --export-method development
```

Kiểm tra IPA ra đúng chưa:

```sh
unzip -q ProxyPin.ipa -d /tmp/ipa
codesign -dv --verbose=2 /tmp/ipa/Payload/Runner.app     # Identifier, Authority, TeamIdentifier
ls /tmp/ipa/Payload/Runner.app/PlugIns                   # phai co ProxyPin.appex
```

## Windows

**Không build được trên macOS.** Flutter không cross-compile; Windows cần host Windows có Visual Studio kèm workload "Desktop development with C++".

Dùng CI: [.github/workflows/release.yml](../.github/workflows/release.yml), chạy tay từ tab Actions hoặc tự động khi push tag `v*`.

## Bẫy chung: đừng đổi nhánh git khi đang build

`git checkout` sửa file ngay dưới chân Xcode/Gradle. Triệu chứng khó đoán:

```
Error (Xcode): Entitlements file "Runner.entitlements" was modified during
the build, which is not supported.
```

Chờ build xong rồi hãy chuyển nhánh.

## Bẫy chung: hết dung lượng

Một vòng build đủ macOS + Android + iOS ngốn hơn 5 GB trong `build/` và `.dart_tool/`. Hết chỗ thì lỗi hiện ra ở chỗ chẳng liên quan gì:

```
strip: can't write output file: .../App.framework/App (No space left on device)
```

Dọn: `rm -rf build .dart_tool` (đều tự sinh lại được).
