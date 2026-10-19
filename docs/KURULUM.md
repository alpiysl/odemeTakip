# iPhone'a Kurulum (ücretsiz Apple ID)

## Bir kerelik hazırlık
1. Xcode → Settings → Accounts → **+** → Apple ID ile giriş yap.
2. iPhone'u kabloyla Mac'e bağla, telefonda "Bu bilgisayara güven" de.
3. iPhone: Ayarlar → Gizlilik ve Güvenlik → **Geliştirici Modu** → Aç → telefon yeniden başlar → onayla.
4. Terminal: `cd ~/Repos/odemeTakipApp && open OdemeTakip.xcodeproj`
5. Xcode'da OdemeTakip target → Signing & Capabilities → Team: **(Personal Team)** seç.

## Kurulum
1. Xcode üst çubuğunda cihaz olarak iPhone'unu seç.
2. **Run** (⌘R). Run şeması Release build alır (hızlı, debug özelliği yok).
3. İlk açılışta "Güvenilmeyen Geliştirici" çıkarsa: iPhone → Ayarlar → Genel → VPN ve Aygıt Yönetimi → geliştirici uygulaması → **Güven**.
4. Uygulama açılınca bildirim iznine **İzin Ver** de.

## Her 7 günde bir (önemli)
Ücretsiz hesapla imza 7 gün geçerli. Süre dolunca uygulama açılmaz.
- 7 gün dolmadan: telefonu bağla → Xcode → Run. Veriler korunur.
- Süre dolduysa da aynı işlem; veriler yine korunur.
- **Uygulamayı telefondan silme** — silersen tüm veriler gider.
- Bildirimler uygulama her açıldığında 12 ay ileriye planlanır; kilitli uygulama açılamazsa yeni planlama yapılmaz, bu yüzden haftalık yenilemeyi aksatma.

## Geliştirici notları
- Proje dosyası XcodeGen ile üretilir: `xcodegen generate` (`project.yml` değişince).
- Testler: `xcodebuild test -project OdemeTakip.xcodeproj -scheme OdemeTakip -destination 'platform=iOS Simulator,name=iPhone 17'`
- İkon: `swift scripts/make-icon.swift OdemeTakip/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
