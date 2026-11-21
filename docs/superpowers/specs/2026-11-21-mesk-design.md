# Meşk — Tasarım Belgesi

- **Tarih:** 21 Kasım 2026
- **Durum:** Onay bekliyor
- **Çalışma adı:** Meşk. Geleneksel usta-çırak öğreniminde "meşk etmek", bir işi ustasına bakarak tekrar tekrar çalışmak demek. İsim istenirse değiştirilir.
- **Görsel taslaklar:** https://claude.ai/artifact/G7E44RvtCjL1WEyb4Uf5iv ("Yazı tipleri" sayfasındaki **1 · Klasik** seçildi)

Belgede "Benim kararım" diye işaretlenen yerleri kullanıcı açıkça söylemedi. Bunlar benim önerim, kullanıcı değiştirebilir.

---

## 1. Amaç

Kullanıcının kendi sözleriyle: "Uygulamayı açtığımda kendi ilerlememi görmek, yeni alışkanlıklar ve yetenekler geliştirmek istiyorum. Kendi ilerlememi takip edebilmek beni motive edecek."

Meşk, kişisel gelişimi bir rol yapma oyunundaki karakter gelişimi gibi gösteren bir mobil uygulama. Kullanıcı yeteneklerine harcadığı saatleri kaydeder. Saatler tecrübeye, tecrübe seviyelere dönüşür. Yetenekler birbirine bağlanır ve Obsidian'daki grafik görünümüne benzer bir ağda izlenir. Karakterin ana statları, yetenekleri ve alışkanlıkları ilerledikçe büyür.

**Başarı ölçütü:** Kullanıcı uygulamayı her gün açar, zamanı zahmetsizce kaydeder, ilerlemesini görüp motive olur ve uygulamayı yıllarca kullanır.

**Kullanıcı ve cihaz:** Tek kullanıcı, yani uygulamayı isteyen kişi. Günlük telefonu iPhone. Android sürümü de olacak.

## 2. Hedefler, hedef dışı olanlar, istenmeyenler

### Hedefler (v1)

1. Saatle ölçülen yetenekler. 1000 saatte 99. seviyeye ulaşılır, ardından 2500, 5000 ve 10000 saatte gizli kademeler açılır.
2. Her seviyenin tekrar etmeyen, kendine ait bir unvanı ve başarımı olur. Gizli kademelerin de kendi adları vardır.
3. Yetenekler arası bağlantılar kurulabilir. Bir yeteneğe çalışılan sürenin %10'u bağlı yeteneklere bonus tecrübe olarak gider. Oran ayarlanabilir.
4. Obsidian benzeri, dokunulabilen ve sürüklenebilen bir yetenek ağı.
5. Bir karakter ekranı: toplam seviye, altı ana stat ve radar grafiği.
6. Tamamen ayarlanabilir bir pomodoro: çalışma süresi, kısa mola, uzun mola ve uzun moladan önceki pomodoro sayısı ayarlanır, ayarlar isimle kaydedilir. Ayrıca serbest kronometre ve elle süre girişi.
7. Alışkanlık takibi: süreli alışkanlıklar zamanlayıcıyla kendiliğinden işaretlenir, basit alışkanlıklar elle işaretlenir. Seriler ve takvim görünümü.
8. Yetenek hedefleri: "100 saat" gibi bir hedef ve isteğe bağlı bir bitiş tarihi. Gereken günlük süre ve tahmini bitiş tarihi kendiliğinden hesaplanır.
9. Veriler cihazda tutulur, hesap gerekmez. Tek dokunuşla yedek dosyası alınır ve geri yüklenir.
10. Türkçe arayüz. Koyu, premium, abartısız renkler ("Klasik" görünüm).

### Hedef dışı (v1'de yok, sonraya kaldı)

- **Finans ve sağlık.** Bunlar ayrı bir beyin fırtınasıyla tasarlanacak. Mimari Servet ve Canlılık statlarına ve sağlık verilerine yer bırakır (bkz. 5.15).
- iPhone kilit ekranında canlı sayaç ve duraklatma (Live Activity / Dynamic Island) ile Android bildiriminden duraklatma/devam. Bunlar v1.1'e kaldı (bkz. 5.7).
- Ana ekran widget'ları, Apple Watch.
- Bulut eşitleme, hesaplar, birden çok cihaz.
- Sosyal özellikler, sıralamalar.
- Açık tema, İngilizce arayüz, tablet ve yatay ekran düzenleri.

### İstenmeyenler (çalışsa bile başarısızlık sayılır)

- Süre kaydetmenin angaryaya dönüşmesi. Zamanlayıcı en fazla iki dokunuşla başlamalı.
- Ucuz ya da çocuksu hissettiren oyunlaştırma: bağıran renkler, konfeti yağmuru, gürültü.
- Yıllarca biriken verinin kaybolması.
- Cezalandıran mekanikler. Zamanla stat düşmez, tecrübe kaybolmaz. Yalnızca kullanıcının yanlış bir kaydı düzeltmesi rakamları geri alabilir.
- Dürüst olmayan rakamlar. Hedefler bonus tecrübeyi saymaz.

## 3. Kısıtlar

- **Teknoloji:** Flutter (stable) ve Dart 3. Hedef platformlar iOS (öncelikli) ve Android. Yalnızca dikey kullanım. En düşük sürümler iOS 15 ve Android 8.0 (API 26) (benim kararım).
- **Geliştirme ortamı:** Linux bulut makinesi. Flutter SDK, Dart testleri, widget ve golden (ekran görüntüsü) testleri ile Chromium'da web derlemesi burada çalışır. iOS burada derlenemez. Android SDK'nın indirildiği `dl.google.com` şu an ağ kuralına takılıyor. Uygulama aşamasında bu sunucu için kullanıcıdan ortam onayı istenecek. Onay verilmezse Android derlemesi sadece GitHub Actions'ta yapılır.
- **iOS dağıtımı:** TestFlight. Kullanıcının Apple Developer Program'a kaydolması gerekir (yılda 99 dolar). Derleme ve TestFlight'a yükleme GitHub Actions'ın macOS makinelerinde yapılır, Mac gerekmez. Özel depolarda macOS dakikaları 10 kat sayılır: ücretsiz 2000 dakika, yaklaşık 200 macOS dakikası demek. Bu yüzden iOS derlemesi her push'ta değil, elle ya da etiketle tetiklenir.
- **Android dağıtımı:** APK. Kullanıcıya doğrudan dosya olarak gönderilir, GitHub'da da indirilebilir. Güncellemelerin eski sürümün üstüne kurulabilmesi için APK'nın hep aynı anahtarla imzalanması gerekir (bkz. 6.4).
- **Sunucu yok.** Uygulama tamamen çevrimdışı çalışır ve kullanıcı dışa aktarmadıkça hiçbir veri cihazdan çıkmaz.
- **Yazı tipleri:** Cormorant Garamond ve Manrope uygulamanın içine gömülür (OFL lisansı). Çalışma anında internetten yazı tipi indirilmez.
- **Yerel ayar:** Türkçe karakterler, `tr_TR` tarih ve sayı biçimi (ondalık virgül, "%27" biçimi). Hafta pazartesi başlar.

## 4. Yaklaşımlar

| Yaklaşım | Artısı | Eksisi | Sonuç |
|---|---|---|---|
| **Flutter** | Aynı kod iPhone ve Android'de çalışır. Özel tasarıma çok uygun. Burada test edilebilir: birim, widget ve golden testleri, web ekran görüntüsü. `health` paketiyle ileride Apple Sağlık ve Health Connect kullanılabilir. | iOS'a özel özellikler (Live Activity) için Swift eklentisi gerekir. | **Seçildi** |
| Yerel Android (Kotlin + Compose) | En iyi Android deneyimi | Kullanıcının günlük telefonu iPhone | Elendi |
| Yerel iPhone (SwiftUI) | En "Apple" his | Burada hiç derlenemez. Her adım uzaktaki macOS sunucusunu bekler, bu da geliştirmeyi yavaşlatır ve hataya açık yapar. | Elendi |
| Telefona kurulan web uygulaması | Kurulumu en kolay yol | Kilitliyken güvenilir bildirim yok, sağlık verisine erişim yok, tarayıcı temizlenince veri kaybolabilir | Elendi |

Kullanıcı önce yerel Android'i seçti, çünkü iPhone'da kendi uygulamasını kullanmak için App Store'da yayınlaması gerektiğini düşünüyordu. TestFlight yolu anlatılınca Flutter'ı seçti.

---

## 5. Ürün kararları

### 5.1 Yetenekler

- Her yeteneğin adı, **ana statı** (zorunlu) ve **ikincil statı** (isteğe bağlı) olur. İsteğe bağlı kısa bir açıklama da eklenebilir.
- Yetenekler arşivlenebilir. Arşivlenen yetenek listelerden ve ağdan gizlenir, ama tecrübesi toplam seviyeye ve statlara katkı vermeye devam eder. Bağlantıları da sürer, yani bağlı yeteneklerden bonus almaya devam eder.
- Yetenek silinirse bütün kayıtları silinir. O kayıtların bağlı yeteneklere verdiği bonus da silinir, yani her şey o yetenek hiç olmamış gibi hesaplanır. Silme öncesindeki onay ekranı bunu rakamla söyler ("Bağlı yeteneklerden 4 sa 20 dk bonus da silinecek"). Yedek almayı ya da silmek yerine arşivlemeyi önerir.
- **Önceki deneyim** (benim kararım): Kullanıcı yeteneği oluştururken ya da sonradan, uygulamadan önce o işe harcadığı süreyi bir kez girebilir. Bu kayıt gerçek süredir: seviyeye ve hedefe sayılır. Ama bağlantı bonusu üretmez, alışkanlıklara ve günlük toplamlara sayılmaz, hız tahminine girmez.
- Yetenek sayısına sınır yok. Ağ yaklaşık 150 yeteneğe kadar akıcı çalışmalı.

### 5.2 Tecrübe ve seviyeler

- **Gerçek süre:** Kullanıcının o yeteneğe gerçekten ayırdığı süre (zamanlayıcı, elle giriş, önceki deneyim). Saniye cinsinden saklanır.
- **Tecrübe:** Gerçek süre artı bağlantı bonusları (bkz. 5.4). Saniye cinsinden.
- **Seviyeyi tecrübe belirler, hedefler gerçek süreyle ölçülür.**
  - Yetenek ekranında ikisi de görünür ("161 sa tecrübe · 148 sa gerçek").
  - Listelerde seviyenin yanında tecrübe saati yazar, çünkü seviyeyi o açıklar.
  - Bugün ve Karakter ekranlarındaki "toplam saat" gerçek sürelerin toplamıdır, önceki deneyim dahil.
- **Eğri:** `L` seviyesi için gereken toplam saat:

  `saat(L) = 1000 × (0,02·x + 0,98·x^2,5)`, burada `x = (L − 1) / 98` ve `L = 1…99`

  saat(1) = 0, saat(99) = 1000. İlk seviyeler çabuk gelir, sonrakiler giderek uzar. İlk pomodoro 2. seviyeye çıkarır. 10 saat 14., 100 saat 39., 500 saat 74. seviye demek. Son seviye yaklaşık 25 saat sürer. Tam tablo Ek A'da.
- Eşikler saniyeye yuvarlanmış sabit bir tablo olarak koda gömülür ve testler bu tabloyu doğrular. Seviye her zaman saklanan sürelerden hesaplanır. Böylece eğri ileride değişse bile hiçbir kayıt kaybolmaz.
- **Bir sonraki seviyeye ilerleme:** `(tecrübe − saat(L)) / (saat(L+1) − saat(L))`. "1,4 sa kaldı" biçiminde gösterilir.
- **Kademeler** (unvanların grupları; ekranda küçük bir alt yazı olarak görünür):
  - Uyanış: 1–9
  - Çıraklık: 10–24
  - Kalfalık: 25–49
  - Ustalık: 50–74
  - Üstatlık: 75–98
  - Pir: 99

### 5.3 Gizli kademeler

- 99. seviyeden sonra tecrübe birikmeye devam eder. Üç gizli kademe vardır:
  - **2500 sa:** Çınar
  - **5000 sa:** Zümrüdüanka
  - **10000 sa:** Efsane
- 99. seviyeye ulaşılana kadar gizli kademelerden hiç söz edilmez. 99'dan sonra yetenek ekranında "Sıradaki: ???" yazan bir ilerleme çubuğu belirir. Çubukta yüzde ve saat görünür, kademenin adı görünmez.
- Kademeye ulaşıldığında özel bir açılış anı yaşanır: ad ortaya çıkar, başarım açılır, yetenek ağdaki görünüşünü değiştirir. Çınar'da altın bir hale, Zümrüdüanka'da çift halka, Efsane'de yavaşça nabız gibi atan bir ışıltı olur.

### 5.4 Bağlantılar ve bonus

- Bağlantılar yönsüzdür (A–B). Bir yetenek kendine bağlanamaz, aynı bağlantı iki kez kurulamaz.
- **Bonus:** A yeteneğine kaydedilen her gerçek sürenin `oran` kadarı, A'ya doğrudan bağlı her yeteneğe ayrı ayrı bonus tecrübe olarak eklenir. Oran bağlantılar arasında bölünmez. Varsayılan oran %10'dur ve ayarlardan %0 ile %25 arasında, %1 adımlarla değiştirilebilir. Bonus zincirleme yayılmaz, B'ye gelen bonus B'nin bağlantılarına geçmez.
- **Bonus, kayıt anında yazılır ve ileriye dönüktür** (benim kararım). Bir süre kaydı kaydedildiğinde o anki bağlantılar ve oranla bonus kayıtları oluşturulur. Sonradan bağlantı eklemek geçmişe bonus vermez, bağlantı silmek de kazanılmış bonusu geri almaz. Oran değişikliği yalnızca yeni kayıtları etkiler.
  - Bir süre kaydı düzenlenirse, ona bağlı bonuslar aynı hedef yeteneklerle ve kaydedildiği andaki oranla orantılı olarak yeniden hesaplanır. Süre kaydı silinirse bonusları da silinir.
  - Önceki deneyim kayıtları bonus üretmez.
- Bonus da tecrübe olduğu için bağlı yeteneklerde seviye atlatabilir ve başarım açabilir. Böyle seviye atlamalar oturum özetinde "Gitar 19. seviyeye ulaştı (bağ bonusu)" diye gösterilir.

### 5.5 Unvanlar ve başarımlar

- **Unvanlar:** 99 seviyenin her birinin kendine ait, tekrar etmeyen bir unvanı vardır. Gizli kademelerin de adları vardır. Liste Ek A'da. Unvanlar bütün yeteneklerde ortaktır.
  - Kilometre taşları Ahilik geleneğinden alındı: Yamak (9) → **Çırak (10)** → **Kalfa (25)** → **Usta (50)** → **Üstat (75)** → **Pir (99)**.
- **Seviye başarımları:** Her yetenekte her seviye bir başarım açar. 1. seviyenin başarımı o yeteneğe ilk süre kaydedildiğinde açılır. Başarımda yetenek adı, seviye, unvan, tek cümlelik bir açıklama ve ilk ulaşılma tarihi bulunur. Açıklamaları uygulamayı yapan kişi yazar, her unvan için bir cümle.
  - Kayıt düzeltmesiyle tecrübe düşerse seviye de düşer ve o seviyelerin başarımları kilitli görünür. Normal kullanımda tecrübe hiç düşmez.
- **Kilometre taşı seviyeleri** (10, 25, 50, 75, 99) daha büyük bir kutlama ve altın çerçeveli bir rozetle gelir. Kademe değişince "Kalfalık kademesine geçtin" yazar.
- **Genel başarımlar:** Yeteneklerden bağımsız, unvanlarla çakışmayan isimlerde başlangıç seti Ek B'de. Sistem veriye dayalıdır, yeni başarım eklemek kolay olmalıdır.
- **Başarımlar ekranı:** Rozetlerden oluşan bir ızgara. Kilitli başarımlar soluk görünür. Gizli kademe başarımları açılana kadar "???" olarak durur.
- **Kutlama:** Seviye atlanınca ekrana bir kart gelir: yetenek adı, "Sv. 24", Cormorant italik büyük harflerle unvan, açıklama cümlesi, ince bir altın ışıltı ve hafif bir titreşim. Konfeti yoktur. Aynı anda birden çok seviye atlanırsa tek bir kartta gösterilir ("Sv. 2 → 5").
- **Sıradaki unvan:** Yetenek ekranında bir sonraki unvan merak uyandırsın diye görünür. "Unvan yolu" ekranında bütün 99 unvan sıralanır: geçilenler parlak, gelecekler soluk, gizli kademeler "???" olarak görünür.

### 5.6 Karakter ve statlar

- **Karakter:** İlk açılışta kullanıcı karakterine bir isim verir, sonradan değiştirebilir. Görünen unvan varsayılan olarak en yüksek seviyeli yeteneğin unvanıdır. Kullanıcı isterse kazandığı herhangi bir unvanı seçebilir (benim kararım).
- **Toplam seviye:** Arşivlenmiş olanlar dahil bütün yeteneklerin seviyelerinin toplamı.
- **Altı ana stat:** Zihin, Beden, Yaratıcılık, Karizma, Denge ve İrade. Servet ve Canlılık ileride eklenecek.
- **Yetenek statları** (Zihin, Beden, Yaratıcılık, Karizma, Denge): Statın değeri, ona ana stat olarak bağlı yeteneklerin seviyelerinin toplamına, ikincil stat olarak bağlı yeteneklerin seviyelerinin yarısının eklenmesiyle bulunur. Ekranda en yakın tam sayıya yuvarlanır. Böylece ana stattaki her seviye +1, ikincil stattaki her seviye +0,5 getirir. Seviye atlayınca "+1 Zihin" gösterilir.
- **İrade** (benim kararım, sabitler sonradan ayarlanabilir):
  - Her tamamlanan alışkanlık 1 İrade puanı verir.
  - Bir alışkanlığın serisi 7, 30, 100 ve 365'e ulaştığında sırasıyla +5, +15, +50 ve +150 ek puan gelir. Bu ödüller her seri için bir kez verilir.
  - İrade = puan / 8, yuvarlanmış.
  - İrade verilerden hesaplanır. Zamanla düşmez, yalnızca kayıt düzeltmeleri etkileyebilir.
- **Radar grafiği:** Eksenler saat yönünde Zihin (üstte), Yaratıcılık, Karizma, İrade, Denge ve Beden. Her eksenin uzunluğu `√(değer / ölçek)`, burada ölçek en büyük stat değerinin 25'in bir sonraki katına yuvarlanmış hali (en az 25). Karekök, küçük statların da görünür kalmasını sağlar.
- **Statın ayrıntısı:** Bir stata dokununca ona katkı veren yetenekler ve katkı miktarları listelenir. İrade için alışkanlıklar listelenir.
- **Genişletilebilirlik:** Statlar "katkı kaynakları"nın toplamı olarak modellenir: yetenekler, alışkanlıklar, ileride finans ve sağlık. Yeni bir kaynak eklemek mevcut hesapları bozmamalı (bkz. 5.15).

### 5.7 Odak: pomodoro ve serbest zamanlayıcı

- **Başlatma:** "Odaklan" düğmesine ya da bir yeteneğin "Başlat" düğmesine basılır. Yetenek ve ayar seti seçilir. Varsayılan olarak son kullanılanlar seçilidir, yani en fazla iki dokunuş gerekir.
- **Pomodoro aşamaları:** Çalışma → kısa mola → çalışma → … → N. çalışmadan sonra uzun mola → döngü kullanıcı bitirene kadar devam eder.
- **Ayar seti** (tamamen özelleştirilebilir, isimle kaydedilir):

  | Alan | Aralık | Varsayılan |
  |---|---|---|
  | Çalışma süresi | 1–180 dk | 25 |
  | Kısa mola | 1–60 dk | 5 |
  | Uzun mola | 1–90 dk | 15 |
  | Uzun moladan önceki pomodoro sayısı | 1–12 | 4 |
  | Molaları otomatik başlat | açık / kapalı | açık |
  | Çalışmayı otomatik başlat | açık / kapalı | kapalı |

  Hazır iki set gelir: "Klasik 25/5" (25/5/15/4) ve "Derin çalışma 50/10" (50/10/30/2). Kullanıcı yeni set ekler, düzenler ve siler. Her yetenek için en son kullanılan set hatırlanır.
- **Otomatik başlatma kapalıysa:** Aşama bitince zamanlayıcı bekler. Çalışma aşamasının süresi aşamanın bitiş anına kadar sayılır, sonrası sayılmaz. Sonraki aşama kullanıcının dokunuşuyla başlar.
- **Serbest mod:** Kullanıcı durdurana kadar ileri sayan bir kronometre.
- **Her iki modda:** duraklat, devam et, bitir. Pomodoroda ayrıca "molayı atla" ve "sonraki aşamaya geç" var.
- **Aynı anda tek oturum:** Bir oturum sürerken yenisi başlatılmak istenirse önce mevcut oturumu bitirmek ya da kaydetmek istenir.
- **Sağlamlık:** Zamanlayıcının durumu (mod, aşama, aşamanın başlangıç zamanı, biriken çalışma süresi, duraklatma) her değişiklikte veritabanına yazılır. Süre saniye saniye saymakla değil, zaman damgalarından hesaplanır. Böylece telefon kilitlense, uygulama arka plana gitse ya da kapatılsa bile süre doğru kalır.
- **Gözetimsiz devam:** Kullanıcı uygulamaya dönmediği halde otomatik başlatma yüzünden birden fazla çalışma aşaması geçmişse, dönüşte bir onay ekranı açılır. Bu aşamalar listelenir, kullanıcı hangilerinin sayılacağını seçer. Serbest modda 4 saati geçince "Zamanlayıcı hâlâ çalışıyor" bildirimi gelir. Bitirirken süre kırpılabilir. Amaç, unutulan bir zamanlayıcının sahte saat üretmemesi.
- **Bildirimler (v1):** Her aşamanın bitişi için zamanlanmış yerel bildirim gönderilir ("Pomodoro bitti · Mola zamanı", "Mola bitti · Odaklanma zamanı"). Bildirime dokununca Odak ekranı açılır. Android'de zamanlayıcı çalışırken süreyi gösteren kalıcı bir bildirim de durur. Ses ve titreşim ayrı ayrı açılıp kapanabilir, bildirim sesi yumuşak bir çandır.
- **v1.1'e kalanlar:** Daha önce "bildirimden durdurup devam ettirebilirsin" denmişti. iPhone'da bu ancak kilit ekranı canlı etkinliğiyle (Live Activity) yapılabiliyor, bu da Swift ile yazılmış ayrı bir iOS eklentisi gerektiriyor. Riskli olduğu için v1'e alınmadı. Android'deki bildirim düğmeleri de aynı sürümde gelecek.
- **Oturumu bitirme:** Bir özet açılır: yetenek (yanlış seçildiyse değiştirilebilir), toplam çalışma süresi (kırpılabilir), tamamlanan pomodoro sayısı ve isteğe bağlı bir not. Kullanıcı "Kaydet" ya da "Vazgeç"i seçer. Bir dakikadan kısa oturumlar kaydedilmez, kullanıcıya bildirilir. Molalar sayılmaz. Oturum tek bir süre kaydı olarak saklanır ve pomodoro sayısı kayıtta tutulur. Kaydedilince bonuslar, seviye atlamalar, alışkanlıklar ve başarımlar işlenir, sonra kutlama kartları gösterilir.
- **Günlük özet:** Bugün ekranında "Bugün 1 sa 15 dk odak · 3 pomodoro" gibi bir satır görünür.

### 5.8 Elle kayıt ve geçmiş

- **Elle giriş:** yetenek, tarih (varsayılan bugün), süre (saat ve dakika), isteğe bağlı başlangıç saati ve not. Geçmiş tarihli giriş yapılabilir. "Önceki deneyim" seçeneği de buradadır (bkz. 5.1).
- **Yetenek geçmişi:** Kayıtlar tarihe göre listelenir. Her kayıt düzenlenebilir ve silinebilir, silmeden önce onay istenir. Düzenleme ve silme 5.4'teki bonus kurallarına göre işlenir.
- **Gün ve zaman:** Kayıtlar UTC zaman damgası ve o anki saat dilimi farkıyla saklanır. Gün hesabı kaydın kendi yerel saatine göre yapılır, böylece seyahat geçmişteki günleri kaydırmaz. Gece yarısını geçen bir oturum başladığı güne sayılır. "Günün başlangıç saati" ayarı varsayılan olarak 00:00'dır ve 00:00 ile 06:00 arasında değiştirilebilir. Bu ayar gece geç saatte çalışanlar içindir (benim kararım).

### 5.9 Alışkanlıklar

- **Süreli alışkanlık:** Bir yeteneğe bağlanır ve günlük dakika hedefi olur, örneğin "İngilizce · 30 dk". O gün o yeteneğe kaydedilen gerçek süre hedefi geçince alışkanlık kendiliğinden tamamlanır. Önceki deneyim kayıtları sayılmaz. Hedefe kadar kısmi bir ilerleme halkası gösterilir. Tamamlanma süre kayıtlarından hesaplanır, ayrıca saklanmaz. Bu yüzden kayıt düzeltmeleri alışkanlığa da kendiliğinden yansır.
- **Basit alışkanlık:** Yaptın ya da yapmadın türünden, elle işaretlenir. İşaret aynı gün içinde geri alınabilir.
- **Program:** her gün, haftanın belirli günleri ya da haftada N kez (gün serbest).
- **Seri:**
  - Her gün ve belirli günler: arka arkaya tamamlanan planlı günler. Planlanmamış günler seriyi bozmaz.
  - Haftada N kez: arka arkaya hedefi tutturan haftalar.
  - Bugün henüz tamamlanmadıysa seri gün bitene kadar bozulmaz.
  - Her alışkanlığın en iyi serisi de saklanır.
- **Bugün ekranı:** O gün planlı alışkanlıklar ve "bugün 1 / 3" sayacı görünür. Haftada N kez olan alışkanlıklar, haftalık hedef tamamlanana kadar her gün "bu hafta 2 / 3" etiketiyle görünür.
- **Hatırlatıcı:** İsteğe bağlı olarak her alışkanlığa bir saat verilir. O saatte, planlı günlerde yerel bildirim gelir (benim kararım).
- **Takvim:** Her alışkanlık ve genel görünüm için aylık bir ısı haritası.
- Bağlı yetenek arşivlenir ya da silinirse süreli alışkanlık da onay alınarak arşivlenir ya da silinir.

### 5.10 Hedefler

- Her yetenekte aynı anda bir **etkin hedef** olabilir. Hedefin bir gerçek süre hedefi (örneğin 100 sa) ve isteğe bağlı bir bitiş tarihi vardır.
- **Gösterilenler:**
  - İlerleme yüzdesi: gerçek süre bölü hedef. Önceki deneyim dahildir.
  - Kalan süre.
  - Bitiş tarihi varsa gereken günlük süre: kalan süre bölü bugün dahil kalan gün sayısı, "31 Mart için günde 34 dk" biçiminde.
  - Tahmini varış tarihi: son 28 günün günlük ortalamasıyla hesaplanır. Yetenek 28 günden yeniyse, ilk kayıttan bu yana geçen günlerin ortalaması kullanılır. Önceki deneyim bu hesaba girmez. Ortalama sıfırsa "Bu hızla tahmin yok" yazar.
- **"Günlük alışkanlığa çevir":** Tek dokunuşla, gereken günlük dakikayı yukarı yuvarlayıp hedef olarak kullanan, her gün tekrarlanan bir süreli alışkanlık oluşturur.
- **Hedef tamamlandığında:** başarım ve kutlama gelir, kullanıcı yeni hedef koyabilir, tamamlanan hedefler geçmişte durur. Bitiş tarihi geçtiği halde hedef tamamlanmadıysa "Süre doldu" yazar ve tarihi uzatma ya da hedefi kapatma seçenekleri sunulur.

### 5.11 Yetenek ağı

- **Yerleşim:** Kuvvete dayalı bir yerleşim kullanılır. Düğümler birbirini iter, bağlantılar yay gibi çeker, hafif bir merkez çekimi ve çarpışma önleme vardır. Simülasyon ağ açılınca çalışır ve oturunca durur. Son konumlar saklanır, böylece ağ her açılışta aynı görünür. Yeni yetenekler bağlı oldukları yeteneklerin yakınına yerleşir.
- **Etkileşim:** Kaydırma, iki parmakla yakınlaştırma ve düğüm sürükleme. Bir düğüme dokununca o düğüm, komşuları ve bağlantıları öne çıkar, diğerleri soluklaşır. Alttaki bilgi kartında ad, seviye, unvan, stat, süre, sıradaki seviyeye kalan süre ve bağlı yetenekler görünür. Karta dokununca yetenek ekranı açılır. Düğüme uzun basınca hızlı eylemler çıkar: "Başlat" ve "Aç".
- **Görünüş:** Taslaktaki gibi. Düğüm çapı `2 × (4 + 1,9 × √seviye)` mantıksal piksel, rengi ana statın rengi, etiketi düğümün altında. Seçili düğümün etrafında altın bir halka ve hafif bir ışıltı olur. Gizli kademeye ulaşmış yetenekler 5.3'teki gibi görünür. Dokunma alanı en az 44 piksel.
- **Süzgeç:** Stat çipleriyle, eşleşmeyenler soluklaşır. Arşivli yetenekler ağda görünmez.
- Ağda iki yetenekten az varsa yönlendiren bir boş ekran gösterilir.

### 5.12 Ekranlar ve gezinme

Altta beş sekme vardır: **Bugün · Yetenekler · Odak · Ağ · Karakter**.

- **Bugün:** Taslaktaki gibi. Tarih, karakter kartı (radar, toplam seviye, toplam saat, yetenek sayısı, altı stat), odak kartı (bugünkü toplam ve "Odaklan" düğmesi), bugünkü alışkanlıklar ve son çalışılan yetenekler (seviye, unvan, ilerleme çubuğu ve varsa hedef satırı).
- **Yetenekler:** Bütün yetenekler son çalışılana, seviyeye ya da ada göre sıralanır, istenirse stata göre gruplanır. "Yeni yetenek" düğmesi burada.
- **Yetenek ekranı:**
  - Büyük seviye numarası ve italik unvan, kademe adı
  - Sıradaki seviyeye ilerleme (99'dan sonra gizli kademe çubuğu)
  - Tecrübe ve gerçek süre, "Başlat" düğmesi
  - Hedef kartı, bağlı yetenekler
  - Son 12 haftanın haftalık süre grafiği (benim kararım; ilerlemeyi görmek için)
  - Sıradaki unvan ve "Unvan yolu", kayıt geçmişi, bu yeteneğin başarımları
  - Düzenleme ekranı: ad, statlar, açıklama, bağlantılar, arşivleme ve silme
- **Odak:** Büyük bir ilerleme halkası, aşama adı, kalan ya da geçen süre, yetenek ve ayar seti seçicileri ve kontrol düğmeleri. Taslağı yok, mevcut görsel dille tasarlanacak.
- **Ağ:** Bkz. 5.11.
- **Karakter:** İsim ve görünen unvan, toplam seviye, büyük radar, stat listesi ve ayrıntıları, başarımlara giriş ve kısa bir "Statlar nasıl hesaplanır?" açıklaması.
- **Başarımlar**, **Unvan yolu**, **Alışkanlık düzenleme ve takvim**, **Elle giriş**, **Oturum özeti**.
- **Ayarlar:** Pomodoro setleri, bonus oranı, günün başlangıç saati, ses ve titreşim, bildirim izinleri, yedekleme (dışa ve içe aktarma, son yedek tarihi) ve hakkında.
- **İlk açılış:** Kısa bir karşılama, karakter adı, hazır yetenek önerilerinden seçim (Ek C, önerilen bağlantılarla) ya da yeni yetenek ekleme, bildirim izni isteği (gerekçesiyle) ve Bugün ekranı.
- **Boş ekranlar:** Her listenin yönlendiren bir boş hali olur.

### 5.13 Görsel dil

Referans: taslak sayfasındaki "1 · Klasik" ekranı. Renkler koyu, sıcak ve abartısız.

**Renkler**

| Belirteç | Değer | Kullanım |
|---|---|---|
| `bg` | `#0E0D0C` | Zemin |
| `surface` | `#161513` | Kartlar |
| `surfaceBorder` | `#24221F` | Kart kenarı |
| `divider` | `#1F1D1A` | Liste ayırıcıları |
| `navBg` | `#121110` | Alt menü |
| `text` | `#EEE9E1` | Ana metin |
| `muted` | `#A39C91` | İkincil metin (zeminde yaklaşık 7:1 kontrast) |
| `faint` | `#8A8379` | Soluk metin ve pasif sekmeler (yaklaşık 5:1) |
| `accent` | `#C9A86A` | Altın vurgu, birincil düğme, seçim |
| `accentHover` | `#DEC089` | Basılı ve aktif hal |
| `track` | `#2A2722` | İlerleme çubuğunun boş kısmı |

**Stat renkleri:** Zihin `#7891B4`, Beden `#B57A60`, Yaratıcılık `#A08BBB`, Karizma `#C995A4`, Denge `#86A78A`, İrade `#ADA491`.

**Yazı tipleri**

- **Cormorant Garamond:** Başlıklarda 600, büyük rakamlarda 500 ağırlıkla kullanılır. Unvanlar 500 ağırlıkta italik yazılır. Rakamlar düz hizalı (lining).
- **Manrope:** Arayüz metinlerinde 400, 500, 600 ve 700 ağırlıklarla kullanılır. Küçük etiketler büyük harf, 10,5 pt ve 0,16 em harf aralıklı.
- **Ölçek:** Ekran başlığı 40, bölüm başlığı 24, büyük sayı 50, seviye numarası 21, arayüz metni 15/14/12/11.

**Biçimler**

- Kart köşe yarıçapı 18, düğme ve çip yarıçapı tam yuvarlak.
- İnce 1 piksel kenarlar kullanılır. Gölge ve renk geçişi kullanılmaz.

**Hareket ve titreşim**

- Animasyonlar sakin (200–300 ms).
- Seviye atlayınca altın bir ışıltı ve unvanın yavaşça belirmesi.
- Başlat ve durdurda hafif, seviye atlayınca orta şiddette titreşim.

**Erişilebilirlik**

- Metin kontrastı en az 4,5:1.
- Dokunma alanı en az 44 piksel.
- Ekran okuyucu etiketleri.
- Sistemin yazı boyutu 1,3 katına kadar desteklenir, sonrası sınırlanır.

### 5.14 Veriler, yedekleme ve gizlilik

- **Depolama:** Cihazda yerel bir SQLite veritabanı. Şema sürümlenir ve geçişler kodla yapılır.
- **Dışa aktarma:** Bütün veriler sürüm numaralı tek bir JSON dosyasına yazılır, örneğin `mesk-yedek-2026-11-21.json`. Dosya sistemin paylaşım ekranıyla Dosyalar, iCloud Drive veya Google Drive'a kaydedilir.
- **İçe aktarma:** Dosya seçilir ve doğrulanır. Mevcut bütün veriler, onay alındıktan sonra, yedekteki verilerle değiştirilir. Eski yedek sürümleri yeni şemaya dönüştürülür.
- **Hatırlatma:** Ayarlarda "Son yedek: 9 gün önce" yazar. 14 günü geçerse Bugün ekranında küçük, kapatılabilir bir hatırlatma çıkar (benim kararım).
- **Gizlilik:** Analitik, reklam veya ağ isteği yoktur. Veri, yalnızca kullanıcı kendisi dışa aktarırsa cihazdan çıkar.

### 5.15 İleriye dönük yer: finans, sağlık ve sonraki özellikler

- Finans (para biriktirme, Servet statı) ve sağlık (kilo, yağ oranı, aktivite, Canlılık statı) ayrı bir beyin fırtınasıyla tasarlanacak.
- v1'deki mimari bunlara yer bırakır:
  - Statlar katkı kaynaklarının toplamı olarak hesaplanır. Yeni bir kaynak eklemek için arayüz uygulamak ve stat listesine bir kayıt eklemek yeterli olmalı.
  - Radar grafiği altıdan fazla ekseni destekler.
  - Başarım sistemi veriye dayalı ve yeni koşul türleri eklenebilir.
  - Sağlık verileri için `health` paketi (Apple Sağlık ve Health Connect) kullanılacak. v1'de bu paket kurulmaz.
- Sonraya kalan özellikler: kilit ekranı canlı sayacı ve bildirim düğmeleri (v1.1), ana ekran widget'ları, otomatik bulut yedeği, Apple Watch, açık tema, İngilizce arayüz.

---

## 6. Teknik kararlar

### 6.1 Kullanılacak paketler (benim kararım)

| Amaç | Seçim |
|---|---|
| Durum yönetimi | `flutter_riverpod` |
| Veritabanı | `drift` (SQLite) ve `sqlite3_flutter_libs` |
| Gezinme | `go_router` |
| Bildirimler | `flutter_local_notifications` ve `timezone` |
| Tarih ve sayı biçimi | `intl` (`tr_TR`) |
| Yedek paylaşımı ve seçimi | `share_plus`, `file_picker`, `path_provider` |
| Çizimler (radar, halkalar, ağ) | `CustomPainter`; grafik kütüphanesi kullanılmaz |
| Titreşim | Flutter'ın `HapticFeedback`'i |

Paket sürümleri uygulama başında güncel kararlı sürümlerden seçilir. Bağımlılıklar az tutulur.

### 6.2 Mimari ve veri modeli

- **Katmanlar:**
  - `lib/domain/`: Saf Dart, Flutter'a bağımlı değil. Eğri ve eşik tablosu, tecrübe ve bonus hesabı, statlar ve İrade, seriler, hedef matematiği, pomodoro durum makinesi, başarım değerlendirmesi ve unvan listesi burada.
  - `lib/data/`: Drift tabloları ve depo sınıfları.
  - `lib/features/<özellik>/`: Ekranlar ve sağlayıcılar.
  - `lib/ui/`: Tema belirteçleri ve ortak bileşenler.
- **Tablolar** (yaklaşık; ayrıntıları uygulamayı yapan belirler):
  - `character`: ad, görünen unvanın kaynağı
  - `skills`: ad, ana ve ikincil stat, açıklama, oluşturma ve arşiv tarihi, ağdaki x ve y konumu, sıra
  - `skill_links`: a, b (a < b)
  - `time_entries`: yetenek, başlangıç ve bitiş (UTC), saat dilimi farkı, süre (saniye), kaynak (`pomodoro`, `free`, `manual`, `prior`), pomodoro sayısı, not
  - `xp_awards`: kaynak kaydı, hedef yetenek, saniye, oran (baz puan)
  - `level_reached`: yetenek, seviye, ulaşılma zamanı
  - `tier_reached`: yetenek, kademe, ulaşılma zamanı
  - `achievements_unlocked`: anahtar, açılma zamanı, bağlam
  - `habits`: ad, tür, yetenek, dakika hedefi, program, hatırlatma saati, arşiv
  - `habit_checks`: alışkanlık, gün
  - `streak_awards`: alışkanlık, kilometre taşı, zaman
  - `goals`: yetenek, hedef saniye, bitiş tarihi, oluşturma ve tamamlanma zamanı
  - `timer_presets`: alanlar 5.7'deki tabloya göre
  - `timer_state`: tek satır
  - `settings`: anahtar ve değer çiftleri
- **Türetilen değerler:** Seviye, statlar, İrade, seriler ve alışkanlık tamamlanması kayıtlardan hesaplanır. Saklanan tek "olay" kayıtları `level_reached`, `tier_reached`, `achievements_unlocked` ve `streak_awards`'tır. Bunlar kutlamaları ve tarihleri tutmak içindir.
- **Tek işlem noktası:** Süre kaydetme, düzenleme, silme ve içe aktarma aynı işlem hattından geçer. Bu hat şu adımları sırayla yapar: bonusu yazar, etkilenen yetenekleri yeniden hesaplar, yeni seviye ve kademeleri işler, başarımları değerlendirir ve kutlama listesini döndürür.

### 6.3 Test ve doğrulama

- Geliştirme test güdümlü yapılır (TDD): domain katmanının her kuralı önce testle yazılır.
- **Birim testleri:**
  - Eşik tablosu ve formül (Ek A'daki değerler)
  - Bonus kuralları: ekleme, düzenleme, silme, önceki deneyim
  - Statlar ve İrade
  - Seri hesapları, üç program türü için; günün başlangıç saati ve saat dilimi uç durumlarıyla
  - Hedef matematiği
  - Pomodoro durum makinesi: otomatik başlatma, duraklatma, gözetimsiz devam
  - Başarım koşulları
- **Widget testleri:** Başlat → bitir → kaydet → kutlama akışı, alışkanlığın kendiliğinden işaretlenmesi, hedeften alışkanlık oluşturma.
- **Golden testleri:** Bugün, Ağ, Odak, Karakter ve Yetenek ekranlarının gömülü yazı tipleriyle ekran görüntüsü karşılaştırması.
- **Görsel kontrol:** Bu makinede `flutter build web` alınır ve Chromium'da ekran görüntüleri çekilir. Kullanıcıya ara aşamalarda bu görüntüler gösterilir.

### 6.4 Derleme ve dağıtım

- **GitHub Actions:**
  - `ci.yml`: Her push'ta Ubuntu üzerinde `flutter analyze` ve `flutter test`.
  - `android.yml`: Ubuntu üzerinde APK derler, artifact olarak yükler. Etiket atılınca GitHub Release'e ekler.
  - `ios.yml`: macOS üzerinde, elle ya da etiketle tetiklenir. Önce `flutter build ios --no-codesign` ile derleme denetlenir. App Store Connect anahtarları tanımlıysa IPA derlenir ve TestFlight'a yüklenir.
- **Android imzası:** Kalıcı bir imza anahtarı oluşturulur ve GitHub Secrets'ta saklanır; depoya konmaz. Kullanıcı birkaç değeri bir kez GitHub ayarlarına ekler, adımlar verilecek. O zamana kadar geçici anahtarla imzalanmış APK'lar gönderilir. Anahtar değişirse güncelleme eski sürümün üstüne kurulmaz. O durumda önce yedek alınır, uygulama silinip yeniden kurulur ve yedek geri yüklenir.
- **iOS kurulumu** (kullanıcının yapacakları; adımlar ayrıca verilecek):
  1. Apple Developer Program'a kaydolmak (onay bir iki gün sürebilir).
  2. App Store Connect'te uygulama kaydı açmak.
  3. Bir App Store Connect API anahtarı oluşturup üç değerini GitHub Secrets'a eklemek.
  4. iPhone'a TestFlight'ı kurmak.
- **TestFlight süresi:** TestFlight derlemeleri 90 gün geçerlidir. Uygulama kapanmasın diye en geç 90 günde bir yeni derleme yüklenmeli. Yeni derleme eskisinin üstüne kurulur ve veriler korunur. Süre dolmadan önce uygulama içinde bir hatırlatma gösterilir (benim kararım).
- **Paket kimliği:** `com.mesk.app` (benim kararım). İlk TestFlight yüklemesinden önce kesinleşmeli, sonra değiştirmek zahmetli.
- **Android SDK:** Bu makinede APK derleyebilmek için `dl.google.com` erişimi, uygulama aşamasının başında ortam onayıyla istenecek.

---

## 7. Uygulamayı yapana bırakılanlar

- Ağ simülasyonunun parametreleri, animasyon süreleri ve geçişleri
- Odak, Karakter, Başarımlar ve Ayarlar ekranlarının ayrıntılı yerleşimi (görsel dile uyarak)
- Her unvan için tek cümlelik açıklamalar, genel başarımların açıklama metinleri, boş ekran ve bildirim metinleri
- Uygulama simgesi (siyah zemin üzerinde altın, düğümlü bir motif) ve bildirim sesi (telifsiz ve yumuşak; gerekirse üretilir)
- Klasör yapısı, sağlayıcıların düzeni, tablo ayrıntıları, JSON yedek biçiminin alanları
- Bildirim izinlerinin akışı, ayrıca Android 12 ve sonrasında kesin alarm izni ile izin verilmezse yaklaşık zamanlamaya düşme
- Hazır yetenek listesinin son hali (Ek C bir başlangıç)

---

## Ek A — Seviye tablosu ve unvanlar

"Toplam" o seviyeye ulaşmak için gereken toplam tecrübe, "Bu seviye" bir önceki seviyeden sonra gereken süre.

| Sv. | Unvan | Toplam | Bu seviye |
|---:|---|---:|---:|
| | **Uyanış** | | |
| 1 | Meraklı | 0 dk | — |
| 2 | Hevesli | 13 dk | 13 dk |
| 3 | Acemi | 28 dk | 15 dk |
| 4 | Çaylak | 46 dk | 18 dk |
| 5 | Gözlemci | 1 sa 09 dk | 22 dk |
| 6 | Kâşif | 1 sa 36 dk | 27 dk |
| 7 | Yolcu | 2 sa 08 dk | 32 dk |
| 8 | Talebe | 2 sa 46 dk | 38 dk |
| 9 | Yamak | 3 sa 30 dk | 44 dk |
| | **Çıraklık** | | |
| 10 | **Çırak** ★ | 4 sa 20 dk | 51 dk |
| 11 | Azimli | 5 sa 18 dk | 58 dk |
| 12 | Gayretli | 6 sa 23 dk | 1 sa 05 dk |
| 13 | Çalışkan | 7 sa 35 dk | 1 sa 13 dk |
| 14 | Sebatkâr | 8 sa 56 dk | 1 sa 21 dk |
| 15 | Kararlı | 10 sa 25 dk | 1 sa 29 dk |
| 16 | Sabırlı | 12 sa 03 dk | 1 sa 38 dk |
| 17 | İstikrarlı | 13 sa 49 dk | 1 sa 47 dk |
| 18 | Disiplinli | 15 sa 45 dk | 1 sa 56 dk |
| 19 | Odaklı | 17 sa 51 dk | 2 sa 05 dk |
| 20 | Becerikli | 20 sa 06 dk | 2 sa 15 dk |
| 21 | Yetenekli | 22 sa 31 dk | 2 sa 25 dk |
| 22 | Hünerli | 25 sa 07 dk | 2 sa 36 dk |
| 23 | Marifetli | 27 sa 53 dk | 2 sa 46 dk |
| 24 | Yetkin | 30 sa 51 dk | 2 sa 57 dk |
| | **Kalfalık** | | |
| 25 | **Kalfa** ★ | 33 sa 59 dk | 3 sa 08 dk |
| 26 | Ehil | 37 sa 19 dk | 3 sa 20 dk |
| 27 | Mahir | 40 sa 50 dk | 3 sa 31 dk |
| 28 | Titiz | 44 sa 33 dk | 3 sa 43 dk |
| 29 | Deneyimli | 48 sa 29 dk | 3 sa 55 dk |
| 30 | Güvenilir | 52 sa 36 dk | 4 sa 07 dk |
| 31 | Zanaatkâr | 56 sa 56 dk | 4 sa 20 dk |
| 32 | Maharetli | 61 sa 29 dk | 4 sa 33 dk |
| 33 | İşbilir | 66 sa 14 dk | 4 sa 46 dk |
| 34 | Özgüvenli | 71 sa 13 dk | 4 sa 59 dk |
| 35 | Akıcı | 76 sa 25 dk | 5 sa 12 dk |
| 36 | Zarif | 81 sa 51 dk | 5 sa 26 dk |
| 37 | Yaratıcı | 87 sa 30 dk | 5 sa 39 dk |
| 38 | Yenilikçi | 93 sa 23 dk | 5 sa 53 dk |
| 39 | Taktisyen | 99 sa 30 dk | 6 sa 07 dk |
| 40 | Sanatkâr | 105 sa 52 dk | 6 sa 22 dk |
| 41 | Kıdemli | 112 sa 28 dk | 6 sa 36 dk |
| 42 | Olgun | 119 sa 19 dk | 6 sa 51 dk |
| 43 | Erbap | 126 sa 25 dk | 7 sa 06 dk |
| 44 | Uzman | 133 sa 45 dk | 7 sa 21 dk |
| 45 | Saygın | 141 sa 21 dk | 7 sa 36 dk |
| 46 | Seçkin | 149 sa 12 dk | 7 sa 51 dk |
| 47 | Rehber | 157 sa 19 dk | 8 sa 07 dk |
| 48 | Öncü | 165 sa 42 dk | 8 sa 23 dk |
| 49 | Kılavuz | 174 sa 20 dk | 8 sa 38 dk |
| | **Ustalık** | | |
| 50 | **Usta** ★ | 183 sa 14 dk | 8 sa 54 dk |
| 51 | Hoca | 192 sa 25 dk | 9 sa 11 dk |
| 52 | Duayen | 201 sa 52 dk | 9 sa 27 dk |
| 53 | Mimar | 211 sa 36 dk | 9 sa 44 dk |
| 54 | Otorite | 221 sa 36 dk | 10 sa 00 dk |
| 55 | Mucit | 231 sa 54 dk | 10 sa 17 dk |
| 56 | Virtüöz | 242 sa 28 dk | 10 sa 34 dk |
| 57 | Bilgin | 253 sa 20 dk | 10 sa 52 dk |
| 58 | Maestro | 264 sa 28 dk | 11 sa 09 dk |
| 59 | Allâme | 275 sa 55 dk | 11 sa 26 dk |
| 60 | Dâhi | 287 sa 39 dk | 11 sa 44 dk |
| 61 | Nadide | 299 sa 41 dk | 12 sa 02 dk |
| 62 | Alp | 312 sa 01 dk | 12 sa 20 dk |
| 63 | Sıra Dışı | 324 sa 39 dk | 12 sa 38 dk |
| 64 | Kudretli | 337 sa 35 dk | 12 sa 56 dk |
| 65 | Eşsiz | 350 sa 49 dk | 13 sa 15 dk |
| 66 | Batur | 364 sa 23 dk | 13 sa 33 dk |
| 67 | Muhteşem | 378 sa 14 dk | 13 sa 52 dk |
| 68 | Emsalsiz | 392 sa 25 dk | 14 sa 11 dk |
| 69 | Bahadır | 406 sa 55 dk | 14 sa 30 dk |
| 70 | Yenilmez | 421 sa 44 dk | 14 sa 49 dk |
| 71 | Rakipsiz | 436 sa 52 dk | 15 sa 08 dk |
| 72 | Kahraman | 452 sa 19 dk | 15 sa 27 dk |
| 73 | Kartal | 468 sa 06 dk | 15 sa 47 dk |
| 74 | Doruk | 484 sa 13 dk | 16 sa 07 dk |
| | **Üstatlık** | | |
| 75 | **Üstat** ★ | 500 sa 40 dk | 16 sa 27 dk |
| 76 | Meşale | 517 sa 26 dk | 16 sa 46 dk |
| 77 | Fener | 534 sa 33 dk | 17 sa 07 dk |
| 78 | Pusula | 551 sa 59 dk | 17 sa 27 dk |
| 79 | Işık | 569 sa 47 dk | 17 sa 47 dk |
| 80 | Yıldız | 587 sa 54 dk | 18 sa 08 dk |
| 81 | Güneş | 606 sa 22 dk | 18 sa 28 dk |
| 82 | Bilge | 625 sa 11 dk | 18 sa 49 dk |
| 83 | Arif | 644 sa 21 dk | 19 sa 10 dk |
| 84 | Hakîm | 663 sa 52 dk | 19 sa 31 dk |
| 85 | Kâhin | 683 sa 44 dk | 19 sa 52 dk |
| 86 | Derya | 703 sa 57 dk | 20 sa 13 dk |
| 87 | Okyanus | 724 sa 32 dk | 20 sa 35 dk |
| 88 | Kâmil | 745 sa 28 dk | 20 sa 56 dk |
| 89 | Ulu | 766 sa 46 dk | 21 sa 18 dk |
| 90 | Yüce | 788 sa 25 dk | 21 sa 40 dk |
| 91 | Kadim | 810 sa 27 dk | 22 sa 01 dk |
| 92 | Zirve | 832 sa 50 dk | 22 sa 23 dk |
| 93 | Abide | 855 sa 36 dk | 22 sa 46 dk |
| 94 | Destan | 878 sa 43 dk | 23 sa 08 dk |
| 95 | Mihenk Taşı | 902 sa 13 dk | 23 sa 30 dk |
| 96 | Nam Salmış | 926 sa 06 dk | 23 sa 53 dk |
| 97 | Unutulmaz | 950 sa 21 dk | 24 sa 15 dk |
| 98 | Ölümsüz | 974 sa 59 dk | 24 sa 38 dk |
| | **Pir** | | |
| 99 | **Pir** ★ | 1000 sa 00 dk | 25 sa 01 dk |

**Gizli kademeler**

| Eşik | Ad |
|---:|---|
| 2500 sa | Çınar |
| 5000 sa | Zümrüdüanka |
| 10000 sa | Efsane |

**Doğrulama değerleri** (testler için): 25 dk → Sv. 2, 1 sa → Sv. 4, 10 sa → Sv. 14, 30 sa → Sv. 23, 100 sa → Sv. 39, 250 sa → Sv. 56, 500 sa → Sv. 74, 730 sa → Sv. 87, 1000 sa → Sv. 99.

## Ek B — Genel başarımlar (başlangıç seti)

| Ad | Koşul |
|---|---|
| İlk Adım | İlk süre kaydı |
| İlk Domates | İlk tamamlanan pomodoro |
| Bereketli Gün | Bir günde 8 pomodoro |
| Derin Dalış | Tek oturumda 2 saat çalışma |
| On Saatlik Yol | Toplam 10 saat gerçek süre |
| Yüz Saat | Toplam 100 saat |
| Bin Saat | Toplam 1000 saat |
| İlk Bağ | İlk bağlantı |
| Takımyıldız | Ağda 10 bağlantı |
| Çok Yönlü | 5 yetenekte Sv. 10 |
| Rönesans | Altı statın hepsi en az 10 |
| Yedi Gün | Bir alışkanlıkta 7 günlük seri |
| Otuz Gün | 30 günlük seri |
| Yüz Gün | 100 günlük seri |
| Kusursuz Hafta | Bir haftada planlı bütün alışkanlıklar tamam |
| Hedefe Varış | İlk tamamlanan hedef |
| Sözünü Tutan | Bir hedefi bitiş tarihinden önce tamamlamak |
| Toplam 100 | Toplam seviye 100 |
| Toplam 250 | Toplam seviye 250 |
| Toplam 500 | Toplam seviye 500 |
| Sabahçı | 07:00'den önce biten bir pomodoro |
| Gece Kuşu | Gece yarısından sonra biten bir pomodoro |
| Dönüş | 14 günden uzun bir aradan sonra bir yeteneğe geri dönmek |

## Ek C — Hazır yetenek önerileri (ilk açılış)

| Yetenek | Ana stat | İkincil stat |
|---|---|---|
| İngilizce | Zihin | Karizma |
| Okuma | Zihin | — |
| Yazılım | Zihin | — |
| Matematik | Zihin | — |
| Satranç | Zihin | — |
| Gitar | Yaratıcılık | — |
| Çizim | Yaratıcılık | — |
| Yazarlık | Yaratıcılık | Zihin |
| Fitness | Beden | — |
| Koşu | Beden | Denge |
| Yoga | Denge | Beden |
| Meditasyon | Denge | — |
| Günlük yazma | Denge | Yaratıcılık |
| Hitabet | Karizma | — |

**Önerilen bağlantılar:**

- İngilizce – Okuma
- İngilizce – Hitabet
- Okuma – Yazarlık
- Okuma – Hitabet
- Yazılım – Matematik
- Matematik – Satranç
- Fitness – Koşu
- Yoga – Fitness
- Yoga – Meditasyon
- Günlük yazma – Meditasyon
- Günlük yazma – Yazarlık
