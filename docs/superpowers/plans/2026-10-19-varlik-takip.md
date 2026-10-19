# Varlık Takip — Uygulama Planı (inline, kısa)

Spec: `docs/superpowers/specs/2026-10-19-odeme-takip-design.md` §15. Executor: inline (aynı oturum), TDD; her task sonunda tam test + commit.

1. **Birim genişletme:** `Currency` altın case'leri, `isGold`, `fiatCases`, sıralama; `MoneyFormatter` altın biçimi. Test: biçim, joined.
2. **Altın fiyatı:** `GoldParser` (truncgil JSON, bozuk/eksik → nil); `ExchangeRates.gold` (opsiyonel, eski cache uyumlu); `rate(for:) -> Decimal?`; `RateStore` iki kaynak, bağımsız hata. Test: parse, merge, eski cache decode, kaynaklardan biri hatalı.
3. **Alacak:** `PaymentKind.receivable`; `Totals.receivable`; borç ekranları/bildirim hariç; `PaymentDraft` alacak mesajları + birim kısıtı. Test.
4. **Birikim modeli:** `@Model Asset` + `AssetMovement`; `AssetSnapshot`; `AssetDraft`, `MovementDraft` (çıkarma ≤ miktar). Test (model + draft).
5. **Net varlık:** `WealthCalculator` (birikim TL, alacak TL, net). Test.
6. **Uygulama kabuğu:** ad, splash (yazısız, ~2 sn), `HomeMode` + ilk açılış seçimi, başlık anahtarı + toast, kur satırı altınlı. DEBUG `-homeMode debt|savings`.
7. **Birikim ekranları:** `SavingsHomeView`, `AssetDetailView`, `AssetFormView`, `AddMovementView`, alacak formu/detayı (Cash ekranları etiket parametresiyle).
8. **UI testleri + ekran görüntüleri:** onboarding, anahtar+toast, birikim ekle/çıkar, alacak tahsilat; mevcut testler `-homeMode debt`.
