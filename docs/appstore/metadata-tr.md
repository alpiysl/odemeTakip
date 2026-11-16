# App Store Connect — Varlık Takip 1.0

App Store Connect'e kopyala-yapıştır için hazır metinler. Karakter sınırları kontrol edildi.

## Uygulama bilgileri (App Information)

| Alan | Değer |
|---|---|
| Ad (Name, ≤30) | Varlık Takip |
| Alt başlık (Subtitle, ≤30) | Borç, kredi ve birikim takibi |
| Ana dil | Türkçe |
| Bundle ID | com.alpiysl.odemetakip |
| SKU | varliktakip001 (istediğin bir kod) |
| Birincil kategori | Finans (Finance) |
| İkincil kategori | Verimlilik (Productivity) — isteğe bağlı |
| Telif (Copyright) | 2026 Varlık Takip (ya da kendi adın) |
| Gizlilik Politikası URL | https://alpiysl.github.io/odemeTakip/privacy.html |
| Destek URL (Support URL) | https://alpiysl.github.io/odemeTakip/support.html |
| Pazarlama URL (isteğe bağlı) | https://alpiysl.github.io/odemeTakip/ |
| Fiyat | Ücretsiz |

## Promosyon metni (Promotional Text, ≤170)

Kredi taksitlerini, elden borçları ve birikimlerini tek ekranda gör. Ödeme dekontu paylaş, PDF rapor al.

## Açıklama (Description)

Varlık Takip; kredi taksitlerini, elden borçlarını, alacaklarını ve birikimlerini tek yerde takip etmen için tasarlandı. Hesap açmana gerek yok, tüm kayıtların yalnızca iPhone'unda kalır.

BORÇLARIN TEK EKRANDA
• Kredi taksitlerini ay ay gör, ödediklerini tek dokunuşla işaretle.
• Elden borçlarına ödeme ekle; kalan tutar kendiliğinden güncellenir.
• Yanlış girdiğin bir ödemeyi düzelt ya da sil.
• Bu ay ödemen gereken toplamı ve toplam kalan borcunu ilk bakışta gör.

BİRİKİM VE ALACAKLAR
• TL, dolar, euro ve gram, çeyrek, yarım, tam, reşat altın birikimlerini kaydet.
• Sana borçlu olanları alacak olarak takip et, tahsilatları ekle.
• Net varlığını (birikimler + alacaklar − borçlar) güncel kurlarla Türk lirası olarak gör.

DEKONT VE RAPOR
• Bir ödemenin dekontunu resim olarak WhatsApp, Mesajlar ya da Mail ile paylaş.
• Tüm kayıtların ya da tek bir kişi/kredi için PDF rapor oluştur; bölümleri ve ay aralığını sen seç.
• Düzeltilen ve silinen ödemeler raporda not olarak görünür; karşı tarafla karışıklık olmaz.

HATIRLATMALAR
• Ay başında ödenecek taksitler için hatırlatma bildirimi al.

GİZLİLİK
• Hesap, reklam ve izleme yok.
• Kayıtların hiçbir sunucuya gönderilmez; yalnızca güncel döviz ve altın fiyatları internetten alınır (TCMB ve finans.truncgil.com).

Fiyat bilgileri bilgilendirme amaçlıdır; yatırım tavsiyesi değildir.

## Anahtar kelimeler (Keywords, ≤100, virgülle, boşluksuz)

borç,kredi,taksit,ödeme,alacak,birikim,altın,döviz,bütçe,hatırlatma,dekont,rapor,elden,çeyrek,kur

## Bu sürümdeki yenilikler (What's New)

İlk sürüm. (1.0 için App Store bu alanı istemez.)

## Yaş derecelendirmesi (Age Rating)

Tüm sorulara "Hayır / None". Kumar, kullanıcı içeriği, web erişimi, sohbet yok. Sonuç: 4+.

## App Privacy (Uygulama Gizliliği)

- "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.**
- Sonuç kartı: **Data Not Collected**.

Gerekçe: Kayıtlar yalnızca cihazda (SwiftData). Kur istekleri hiçbir kullanıcı verisi içermez. Analitik, reklam ve izleme SDK'sı yok.

## İhracat uyumluluğu (Export Compliance)

`ITSAppUsesNonExemptEncryption = false` Info.plist'te tanımlı. Yalnızca standart HTTPS kullanılıyor, bu yüzden App Store Connect bu soruyu sormaz.

## İnceleme bilgileri (App Review Information)

- Giriş gerekli mi (Sign-in required): **Hayır**
- İletişim: kendi adın, telefonun, alpiysll@gmail.com
- Notlar (Notes) — İngilizce yaz; inceleme ekibi İngilizce çalışır:

```
Varlık Takip is a personal debt, loan installment and savings tracker (Turkish UI).
No account or login. All records are stored only on the device (SwiftData).
The only network access is fetching public exchange rates (tcmb.gov.tr) and gold
prices (finans.truncgil.com); no user data is sent anywhere. No ads, analytics or tracking.

How to try the main features (the app starts empty):
1. On first launch choose "Borç Takip" (debts). The "Borç / Birikim" switch at the
   top changes between debts and savings later.
2. Tap "Yeni ödeme" at the bottom. Add a loan: type "Kredi", name, installment
   count (e.g. 12), monthly amount (e.g. 1000), first month. Save.
3. Open the loan and tap a month row to mark that installment as paid.
4. Tap "Yeni ödeme" again, switch the segment to "Elden" (cash debt), enter a
   name and total (e.g. 5000). Save, open it and tap "+ Ödeme ekle" to add a payment.
5. Receipt sharing: long-press a payment row (or swipe right) -> "Dekontu paylaş".
   Choosing "Save Image" in the share sheet asks for Photos add-only permission.
6. Editing: tap a payment row to correct its amount/date or delete it.
7. Reports: the document icon on the home header creates a PDF report for all
   records; the document icon on a detail screen creates one for that record only.
8. "Birikim" tab: add savings in TRY, USD, EUR or gold units, and receivables.
9. Local notifications remind the user of installments due this month.

Rates are informational only; the app does not offer trading, lending or payments.
```

## Ekran görüntüleri

`docs/appstore/screenshots/` klasöründe, 6,9 inç (1320 × 2868) iPhone boyutunda. App Store Connect'te "iPhone 6.9" Display" alanına sırayla yükle. Daha küçük ekran boyutlarını App Store bunlardan otomatik üretir.
