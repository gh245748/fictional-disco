# iPhone'a kurulum (TestFlight)

Bu rehber, Meşk'i kendi iPhone'una TestFlight ile kurman içindir. Kod bilmen gerekmez. Adımları sırayla yap. Bir kez kurduktan sonra yalnızca 7. adım tekrar eder.

Gerekenler: bir Mac gerekmez. Bir iPhone, bir Apple kimliği (Apple ID) ve yıllık 99 dolarlık Apple Developer üyeliği yeterli. Derlemeyi GitHub senin yerine yapar.

## 1. Apple Developer Program'a kaydol

1. Tarayıcıda https://developer.apple.com/programs/enroll/ adresine git.
2. Kendi Apple kimliğinle giriş yap. İki adımlı doğrulama açık olmalı.
3. Bireysel (Individual) üyeliği seç ve ödemeyi yap.
4. Onay bir iki gün sürebilir. Onay e-postası gelmeden sonraki adımlara geçme.

## 2. App Store Connect'te uygulamayı oluştur

1. https://appstoreconnect.apple.com adresine git ve aynı Apple kimliğiyle giriş yap.
2. "Apps" (Uygulamalar) bölümünde artı düğmesine, sonra "New App" (Yeni Uygulama) seçeneğine bas.
3. Şunları gir:
   - Platform: iOS
   - Name: Meşk (bu ad başkası tarafından alınmışsa "Meşk Günlük" gibi bir ad dene; telefondaki adı bundan etkilenmez)
   - Primary Language: Turkish
   - Bundle ID: com.mesk.app (listede yoksa önce https://developer.apple.com/account/resources/identifiers adresinden "+" ile bu kimliği ekle)
   - SKU: mesk (herhangi bir kelime olabilir)
4. "Create" düğmesine bas.

## 3. App Store Connect API anahtarı oluştur

1. App Store Connect'te "Users and Access" (Kullanıcılar ve Erişim) bölümüne, oradan "Integrations" (Entegrasyonlar) sekmesine, sonra "App Store Connect API" bölümüne git.
2. "Generate API Key" (veya "+") düğmesine bas.
3. Ad olarak "Mesk GitHub" yaz, erişim olarak **Admin** seç ve oluştur. (Admin gerekir: GitHub'daki derleme, imza sertifikasını senin adına Apple'dan otomatik oluşturur ve App Manager yetkisi buna her zaman yetmez.) Bu anahtar çok güçlüdür: gizli tut, kimseyle paylaşma. Şüphelendiğin an aynı sayfadan "Revoke" (İptal et) ile iptal edebilirsin; yenisini oluşturup 4. adımdaki değerleri güncellersin.
4. Açılan listede şu iki değeri not al:
   - **Issuer ID**: sayfanın üstünde, uzun bir kod (örneğin 69a6de80-...). Bu, 4. adımdaki `ASC_ISSUER_ID` olacak.
   - **Key ID**: yeni anahtarın satırında, 10 karakterlik kod. Bu, `ASC_KEY_ID` olacak.
5. Anahtarın satırındaki "Download API Key" düğmesine bas ve `AuthKey_XXXX.p8` dosyasını indir. **Bu dosyayı yalnızca bir kez indirebilirsin.** Güvenli bir yere kaydet ve kimseyle paylaşma.
6. Apple Team ID'ni bul: https://developer.apple.com/account adresinde "Membership details" (Üyelik ayrıntıları) bölümünde 10 karakterlik "Team ID" yazar. Bu, `APPLE_TEAM_ID` olacak.

## 4. GitHub'a dört değeri ekle

1. GitHub'da Meşk deposunu aç. "Settings" (Ayarlar), "Secrets and variables", "Actions" bölümüne git.
2. "New repository secret" düğmesine basarak aşağıdaki dört değeri tek tek ekle. Ad kutusuna adı, değer kutusuna değeri yaz.

| Adı | Değer nereden gelir |
|---|---|
| `ASC_KEY_ID` | 3. adımdaki Key ID (10 karakter) |
| `ASC_ISSUER_ID` | 3. adımdaki Issuer ID (uzun kod) |
| `ASC_KEY_P8_BASE64` | İndirdiğin `.p8` dosyasının base64 hali (aşağıya bak) |
| `APPLE_TEAM_ID` | 3. adımdaki Team ID (10 karakter) |

`.p8` dosyasının base64 halini almak için:

- Mac'te Terminal'de: `base64 -i AuthKey_XXXX.p8 | pbcopy` yaz. Sonuç panoya kopyalanır, değer kutusuna yapıştır.
- Windows'ta PowerShell'de: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8")) | Set-Clipboard` yaz ve yapıştır.
- Elinde bilgisayar yoksa dosyanın içeriğini bir "base64 encode" sitesine yapıştırma. Anahtar gizli kalmalı. Bunun yerine bir arkadaşından ya da bir bilgisayardan yardım iste.

Bu değerler gizlidir: GitHub bir daha göstermez, kimseye göndermene gerek yok.

## 5. "iOS" iş akışını çalıştır

1. Deponun "Actions" sekmesini aç.
2. Soldaki listeden **iOS**'u seç.
3. Sağdaki "Run workflow" düğmesine, sonra yeşil "Run workflow" düğmesine bas.
4. Yaklaşık 15–25 dakika bekle. Yeşil tik çıkınca derleme tamam ve TestFlight'a yüklenmiş demektir. Kırmızı çarpı çıkarsa işin adına tıkla ve hatanın ekran görüntüsünü uygulamayı geliştiren kişiye gönder.
5. Yükleme bittikten sonra Apple birkaç dakika "işleme" yapar. App Store Connect'te uygulamanın "TestFlight" sekmesinde derlemenin görünmesini bekle.
6. Uygulama özel bir şifreleme kullanmadığı için Apple'ın "Export Compliance" sorusu çıkmaz; ayar uygulamanın içinde hazırdır. Yine de sorarsa "None of the algorithms mentioned above" seçeneğini işaretle.

## 6. Kendini test kullanıcısı yap, TestFlight'ı kur ve derlemeyi kabul et

1. App Store Connect'te uygulamanı aç ve üstteki **TestFlight** sekmesine git.
2. Solda "Internal Testing" (Dahili Test) yanındaki artı düğmesine bas ve bir grup oluştur (adı "Ben" olabilir).
3. Grubun içinde "Testers" bölümünden kendi Apple kimliğini ekle. Seni e-postayla davet eder.
4. Grup ayarlarında yeni derlemelerin otomatik dağıtılması (automatic distribution) seçeneğini aç. Böylece sonraki sürümler sana kendiliğinden gelir.
5. iPhone'una App Store'dan **TestFlight** uygulamasını indir.
6. E-postadaki daveti iPhone'unda aç (ya da TestFlight'ı aç ve aynı Apple kimliğiyle giriş yap). Meşk listede görünecek.
7. "Install" (Kur) düğmesine bas.

## 7. 90 gün dolmadan yeni sürüm yükle

TestFlight sürümleri **90 gün** sonra çalışmayı bırakır. Uygulama kapanmasın diye en geç 90 günde bir 5. adımı tekrar et. Yeni sürüm eskisinin üstüne kurulur, verilerin silinmez.

- Meşk, sürüm 80 günü geçince Bugün ve Ayarlar ekranlarında "Bu TestFlight sürümü N gün içinde sona erecek. Yeni bir sürüm yükle." diye hatırlatır.
- Yine de takvimine her 2 ayda bir tekrar eden bir not ekleyebilirsin.
- Süresi dolmuş bir sürüm açılmaz. Böyle olursa önce yeni sürümü yükle. Verilerin telefonda durur, yeni sürümle geri gelir. Yine de Ayarlar'dan düzenli yedek almak iyi olur.
