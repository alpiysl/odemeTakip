# Ödeme Takip — Tasarım Dokümanı

Tarih: 2026-10-19
Durum: Onaylandı (2026-10-19); 13–14 sonradan eklendi ve onaylandı

## 1. Amaç

Sadece tek kullanıcının (geliştiricinin kendisi) iPhone'unda çalışacak, kredi ve elden borç ödemelerini takip eden sade bir iOS uygulaması. Başarı kriterleri:

- Her kaydın ve tüm kayıtların kalan borcu tek bakışta görülür (kredi / elden ayrı + toplam).
- Kredi taksitleri ay ay işaretlenir; ödenen ay yeşil ✓, kalan anında düşer.
- Elden ödemelerde o ay ödenen tutar ödeme anında manuel girilir.
- Her ayın 1'inde kredi ve elden ödemeleri ayrı satırlarda gösteren bildirim gelir.
- Kullanım sırasında telefonda hata/çökme görülmez.

## 2. Kararlar

| Konu | Karar |
|---|---|
| Platform | Sadece iOS, iPhone, iOS 17+ |
| Teknoloji | SwiftUI + SwiftData, harici bağımlılık yok. Tek ağ erişimi: TCMB kur bülteni (bkz. 13) |
| Ödeme türleri | Kredi, Elden |
| Kredi | Taksit sayısı + aylık tutar + ilk taksit ayı (+ önceden ödenen taksit sayısı) |
| Elden | Toplam borç; her ödeme tutarı ödeme anında girilir, sabit taksit yok |
| Para birimi | Kayıt bazında: TL, USD, EUR. Kur varsa ana sayfa toplamları ve bildirim TL'ye çevrilir (bkz. 13); kur yoksa para birimine göre ayrı |
| Bildirim | Local notification (APNs/sunucu yok) |
| İmza | Ücretsiz Apple ID; kurulum 7 günde bir Xcode ile yenilenir. Bundle ID sabit: `com.alpiysl.odemetakip` (yeniden kurulumda veri korunur) |
| Dil | Türkçe arayüz, `tr_TR` sayı/tarih biçimi |

## 3. Görsel tasarım (onaylandı)

Stil "C2": C düzeni + B renk paleti.

- Zemin `#0b0b0f`, yüzey `#1c1c22`, ayraç `#1f1f26`, alt bilgi paneli `#15151b`.
- Vurgu: mor gradyan `#5e5ce6 → #bf5af2` (özet kartı, seçili sekme, + butonu, birincil buton).
- Kredi rengi `#64d2ff`, elden rengi `#ffd60a`, ödendi rengi `#30d158`.
- Sadece koyu tema (uygulama `preferredColorScheme(.dark)`).
- Logo: **B** — koyu zemin, üstte mor gradyan tuşta beyaz "+", altta gri (`#26262e`) tuşta sarı "−".

Onaylanan mockup dosyaları: `.superpowers/brainstorm/*/content/all-screens-v3.html`, `logo.html`.

## 4. Ekranlar

### 4.1 Ana sayfa
- Gradyan özet kartı: "Toplam kalan" (ana para birimi büyük, diğerleri altında `+ $2.400` şeklinde), altında Kredi ve Elden kalanları, en altta "Bu ay" çipi.
- "Bu ay" çipi: bu ay vadesi gelen **ödenmemiş** kredi taksitlerinin toplamı (`Bu ay: ₺22.500 kredi taksiti`). Hepsi ödendiyse `Bu ayın taksitleri ödendi ✓`. Bu ay taksit yoksa çip gizlenir.
- Ana para birimi: kalanı olan kayıtlarda en çok kullanılan para birimi; eşitlikte TL.
- Sekmeler: Tümü / Kredi / Elden.
- Liste satırı: ikon (emoji), ad, alt satır (kredi: `14/36 taksit · ₺15.000/ay`, elden: `Elden · ₺30.000 ödendi`), sağda kalan tutar.
- Kalanı 0 olan kayıtlar "Tamamlananlar" bölümünde, soluk, listenin sonunda.
- Sağ altta gradyan + butonu → ekleme formu.
- Kayıt yoksa boş durum: "Henüz ödeme yok — + ile ekle".

### 4.2 Kredi detay
- Başlık: ikon + ad; alt bilgi: `36 taksit · ₺15.000/ay · Eyl 2025 başlangıç`.
- Taksit listesi (ay adı + taksit no + tutar). Bu ayın satırı vurgulu.
- Satıra/daireye dokunma ödendi ↔ ödenmedi geçişi yapar; ödendi = yeşil ✓, tutar yeşil. Hafif titreşim (haptic).
- Liste açılışta bu aya kaydırılır. Bu aydan önceki ve hepsi ödenmiş aylar "Önceki N taksit ödendi ✓ (göster)" satırına katlanır.
- Sabit alt panel: Toplam, Ödenen (adet) `− tutar`, **Kalan (adet)**.
- Sağ üst "Düzenle": ad, ikon, aylık tutar, taksit sayısı, ilk ay düzenlenir; silme (onay diyaloğu).

### 4.3 Elden detay
- Başlık: ikon + ad; alt bilgi: `Elden · Toplam borç ₺80.000`.
- "+ Ödeme ekle" butonu → sayfa: tutar (zorunlu, > 0, ≤ kalan), tarih (varsayılan bugün).
- Ödeme geçmişi (yeniden eskiye): ay, gün, tutar. Sola kaydırarak silme.
- Sabit alt panel: Toplam borç, Ödenen (adet) `− tutar`, **Kalan**.
- "Düzenle": ad, ikon, toplam borç (ödenenden az olamaz), silme.

### 4.4 Ekleme formu
- Üstte Elden / Kredi seçimi.
- Ortak: Ad, İkon (hazır emoji listesi), Para birimi.
- Kredi: Taksit sayısı (1–480), Aylık tutar, İlk taksit ayı, Önceden ödenen taksit (0…taksit sayısı; ilk N taksit ödendi işaretlenir).
- Elden: Toplam borç.
- Altta canlı özet (kredi: Toplam, Kalan, Son taksit ayı).
- Zorunlu alan boş / sıfır / geçersizken "Kaydet" pasif.

### 4.5 Bildirim
- Her ayın 1'i 09:00.
- Başlık: `Kasım ödemeleri`
- Gövde (ayrı satırlar):
  - `Kredi: ₺22.500 (2 taksit)` — o ay vadesi gelen ödenmemiş taksitler, para birimine göre (`₺22.500 + $300`).
  - `Elden kalan: ₺50.000 + $2.400` — kalan elden borç.
- O ay ne kredi taksiti ne elden borç varsa bildirim planlanmaz.

## 5. Veri modeli (SwiftData)

```
Payment
  id: UUID
  name: String
  icon: String            // emoji
  kindRaw: String         // "credit" | "cash"
  currencyRaw: String     // "TRY" | "USD" | "EUR"
  createdAt: Date
  // kredi
  installmentCount: Int
  monthlyAmount: Decimal
  firstInstallmentMonth: Date   // ayın 1'i, takvim normalize
  paidInstallmentIndexes: [Int] // 0 tabanlı
  // elden
  totalDebt: Decimal
  cashPayments: [CashPayment]   // cascade delete

CashPayment
  id: UUID
  amount: Decimal
  date: Date
```

Tutarlar `Decimal` (kayan nokta hatası yok).

## 6. İş mantığı

Saf, test edilebilir tipler; SwiftUI'den bağımsız:

- `PaymentCalculator`
  - kredi: toplam = adet × aylık; ödenen = ödenmiş adet × aylık; kalan = toplam − ödenen.
  - elden: ödenen = Σ ödemeler; kalan = max(0, toplam borç − ödenen).
  - `installmentMonth(index)` = ilk ay + index ay.
  - `dueThisMonth(payments, month)` → para birimine göre ödenmemiş taksit toplamı + adet.
  - `totals(payments)` → para birimine göre kredi kalan, elden kalan, genel kalan.
- `NotificationContentBuilder` — verilen ay ve kayıtlardan başlık/gövde üretir (veya `nil`).
- `MoneyFormatter` — `tr_TR` biçim, sembol: ₺ / $ / €, kuruş yalnızca küsurat varsa.

## 7. Bildirim planlama

- `NotificationScheduler`: tüm bekleyen bildirimleri siler, önümüzdeki 12 ayın her biri için `UNCalendarNotificationTrigger` (gün 1, saat 09:00, tekrarsız) ekler. İçerik planlama anındaki veriye göre.
- Tetiklenme: uygulama açılışı, öne gelme (`scenePhase == .active`), her veri değişikliği.
- İzin ilk açılışta istenir. Reddedilirse uygulama normal çalışır; ana sayfada kapatılabilir küçük bir bilgi satırı "Bildirimler kapalı — Ayarlar'dan açabilirsin".

## 8. Hata önleme (madde 8)

- `fatalError`, force unwrap (`!`), `try!` kullanılmaz.
- `ModelContainer` oluşturulamazsa: bellek içi container ile açılır, ana sayfada uyarı satırı (çökme yok).
- Kaydetme hataları yakalanır, `Logger` ile loglanır; kullanıcı akışı bozulmaz.
- Tüm girişler doğrulanır (bkz. 4.3, 4.4); geçersiz değer kaydedilemez.
- Taksit sayısı, ödenmiş en büyük taksit indeksinin altına düşürülemez.
- Tarih hesapları `Calendar(identifier: .gregorian)` + sabit `tr_TR` locale ile.
- Ağ, izin veya dış servis bağımlılığı yok.

## 9. Proje yapısı

```
odemeTakipApp/
  project.yml                 # XcodeGen
  OdemeTakip/
    App/OdemeTakipApp.swift
    Models/Payment.swift, CashPayment.swift
    Logic/PaymentCalculator.swift, NotificationContentBuilder.swift, MoneyFormatter.swift
    Services/NotificationScheduler.swift
    Views/Home/…, Views/CreditDetail/…, Views/CashDetail/…, Views/AddPayment/…, Views/Components/…
    Theme/Theme.swift
    Resources/Assets.xcassets (AppIcon 1024px, tek boyut)
  OdemeTakipTests/            # Swift Testing
```

- Xcode projesi XcodeGen ile üretilir (kurulu değilse `brew install xcodegen`, kullanıcı onayıyla).
- App icon: logo B, 1024×1024 PNG, betikle üretilir.

## 10. Test

- Birim testleri: `PaymentCalculator` (kalanlar, çoklu para birimi, ay hesapları, yıl geçişi, önceden ödenen taksit), `NotificationContentBuilder` (sadece kredi, sadece elden, ikisi, hiçbiri → nil), `MoneyFormatter`.
- `xcodebuild test` simülatörde.
- Elle simülatör kontrolü: kayıt ekle, ay işaretle, elden ödeme ekle/sil, toplamların güncellenmesi, gizli debug ile 5 sn sonraya test bildirimi (sadece DEBUG build).

## 11. Kurulum

- Telefona Xcode ile kurulum talimatı: Developer Mode açma, geliştirici sertifikasına güvenme, 7 günde bir yeniden "Run".

## 12. Kapsam dışı

iCloud senkronizasyonu, widget, iPad, açık tema, grafik/istatistik ekranı.

## 13. Döviz kuru (sonradan eklendi, onaylı)

- Kaynak: TCMB `https://www.tcmb.gov.tr/kurlar/today.xml`, USD ve EUR **ForexSelling** (döviz satış), `Unit` ile bölünür.
- Açılışta ve uygulama öne gelince, son kur 6 saatten eskiyse çekilir; zaman aşımı 8 sn. Son kur `UserDefaults`'ta saklanır.
- Hata/ağ yok/bozuk yanıt: sessizce log, son kur korunur. Hiç kur yoksa toplamlar para birimine göre ayrı gösterilir, kur satırında "Kur bekleniyor".
- TL karşılıkları tam liraya yuvarlanır (`CurrencyConverter.toTRY`).
- Ana sayfa: toplam, Kredi/Elden lejantı ve "Bu ay" çipi TL; kartın altında kur satırı `1$ = ₺49,55 · 1€ = ₺55,57 · TCMB 19 Eki`; döviz kayıt satırlarında `≈ ₺118.926`.
- Bildirim: kredi ve elden satırları TL toplamı (kur yoksa eski biçim). Detay ekranları kaydın kendi para biriminde kalır.

## 14. Splash

- Koyu zeminde logo B: + tuşu, sonra − tuşu basılır, "Ödeme Takip" belirir; ~1,1 sn sonra yumuşak geçişle ana sayfa. Kur çekme bu sırada başlar.
