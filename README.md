# Meşk

Meşk, bir beceride harcadığın emeği ve ilerlemeyi takip eden, Türkçe bir telefon uygulamasıdır. Çalıştığın her dakika o yeteneğin seviyesine dönüşür; seviyeler, unvanlar ve başarımlar ilerlediğini gözle görmeni sağlar. Her şey telefonunda kalır, internet bağlantısı ya da hesap gerekmez.

## Neler yapabilir?

- **Yetenekler ve seviyeler:** Her yetenek 1–99 arasında seviye atlar. 99. seviye 1000 saat demektir. 99'dan sonra, ancak oraya varınca ortaya çıkan gizli kademeler gelir.
- **Unvanlar ve başarımlar:** 99 seviyenin her birinin kendine ait bir unvanı vardır. Ayrıca genel başarımlar açılır.
- **Bağlı yetenekler:** İki yeteneği birbirine bağlarsan birine harcadığın süre, diğerine küçük bir bonus olarak da yazılır.
- **Yetenek ağı:** Bütün yeteneklerini ve bağlantılarını bir ağ görünümünde görürsün.
- **Karakter ve statlar:** Zihin, Beden, Yaratıcılık, Karizma, Denge ve İrade statların radar grafiğinde görünür.
- **Zamanlayıcı:** Pomodoro ya da serbest kronometre; süreleri istediğin gibi ayarlayabilir, hazır setleri kullanabilir ya da kendi setini kaydedebilirsin.
- **Alışkanlıklar:** Zamanlayıcıya bağlı (örneğin günde 30 dakika) ya da basit alışkanlıklar, seri takibi ve takvimle.
- **Hedefler:** Bir yetenek için saat hedefi koyarsın; uygulama günlük gereken süreyi ve bu hızla ne zaman varacağını gösterir.
- **Yedekleme:** Verini tek bir dosyaya yedekler, istediğinde geri yüklersin. Geri yüklemeyi bir kez geri alabilirsin.

## Android'e kurulum

1. GitHub'da bu projenin **Actions** sekmesinden son başarılı **Android** çalışmasını aç ve en alttaki **mesk-apk** dosyasını indir (ya da sana sohbette gönderilen APK'yı kullan).
2. İndirdiğin zip'ten APK dosyasını çıkar.
3. Telefonda dosyaya dokun. İstenirse "bilinmeyen kaynaklardan yüklemeye izin ver" ayarını aç.
4. Kur ve uygulamayı aç.

Güncelleme yaparken verilerin ancak yeni APK eskisiyle **aynı anahtarla imzalanmışsa** korunur. Anahtarın nasıl hazırlanacağı için: [docs/kurulum/android-imza.md](docs/kurulum/android-imza.md).

## iPhone'a kurulum (TestFlight)

iPhone'a kurulum TestFlight üzerinden yapılır. Adım adım anlatım: [docs/kurulum/ios-testflight.md](docs/kurulum/ios-testflight.md).

TestFlight sürümleri **90 gün** sonra sona erer. Bunu unutmaman için uygulama, süre dolmadan önce Bugün ve Ayarlar ekranlarında sana hatırlatma gösterir; bu durumda yeni bir sürüm yüklemen yeterli.

## Verilerin

- Her şey telefonunda durur. Uygulama internete bağlanmaz, analiz ya da reklam göndermez.
- Telefonunun kendi iCloud ya da Google yedeği açıksa Meşk'in verisi o yedeğe dahil olabilir.
- Yine de **Ayarlar → Yedek al** ile düzenli olarak yedek almanı öneririz. Yedek dosyasını Dosyalar, iCloud Drive ya da Google Drive'a kaydedebilirsin. 14 günden uzun süre yedek almazsan Bugün ekranında bir hatırlatma çıkar.
- Geri yüklerken yedeğin tarihi ve içindeki yetenek, kayıt ve alışkanlık sayısı gösterilir; onay vermeden hiçbir şey değişmez. Yanlış dosyayı yüklersen Ayarlar'daki "Geri yüklemeden önceki veriye dön" ile bir kez geri dönebilirsin.

## Geliştirici notları

- Flutter 3.50.1. Testler: `flutter test`; kod denetimi: `flutter analyze`.
- Görsel (golden) testler yalnızca Linux'ta güvenilir çalışır: `flutter test --tags golden`. Görselleri yenilemek için `flutter test --update-goldens --tags golden <dosya>`.
- GitHub iş akışları: `.github/workflows/ci.yml` (analiz ve testler), `android.yml` (imzalı APK), `ios.yml` (TestFlight yüklemesi).
- Tasarım belgesi: [docs/superpowers/specs/2026-11-21-mesk-design.md](docs/superpowers/specs/2026-11-21-mesk-design.md)
- Uygulama planı: [docs/superpowers/plans/2026-11-23-mesk-v1.md](docs/superpowers/plans/2026-11-23-mesk-v1.md)
