# Android imzası (keystore) kurulumu

Telefona kurulan her Android uygulaması bir anahtarla imzalanır. Meşk'in güncellemelerinin eskisinin üstüne kurulabilmesi için her seferinde **aynı anahtar** kullanılmalıdır. Anahtarı bir kez oluşturur, güvenli bir yerde saklarsınız.

Anahtar tanımlamazsanız APK yine derlenir (geçici "debug" anahtarıyla). Telefonunuza kurup denemek için bu yeterlidir; ama anahtar sonradan değişirse aşağıdaki "Anahtarı değiştirmek" bölümü geçerli olur.

## 1. Anahtarı oluşturun

Bilgisayarınızda (Java kurulu olmalı) bir terminal açıp şunu çalıştırın:

```
keytool -genkey -v -keystore meskkey.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mesk
```

Sizden bir şifre ve birkaç bilgi isteyecek. Şifreyi not edin. Ortaya `meskkey.jks` dosyası çıkar.

**Bu dosyayı ve şifreyi yedekleyin** (şifre yöneticisi, USB bellek gibi). Kaybederseniz aynı imzayla güncelleme yapamazsınız. Dosyayı asla GitHub'a yüklemeyin.

## 2. GitHub'a dört gizli değer ekleyin

Önce dosyayı metne çevirin:

```
base64 -w 0 meskkey.jks
```

(Mac'te: `base64 -i meskkey.jks`.) Çıkan uzun metni kopyalayın.

GitHub'da depoya girin: **Settings > Secrets and variables > Actions > New repository secret**. Şu dört değeri ekleyin:

| Ad | Değer |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Az önce kopyaladığınız uzun metin |
| `ANDROID_KEYSTORE_PASSWORD` | Anahtarı oluştururken verdiğiniz şifre |
| `ANDROID_KEY_ALIAS` | `mesk` |
| `ANDROID_KEY_PASSWORD` | Aynı şifre (keytool tek şifre sorduysa aynısı) |

## 3. APK'yı derleyin

Depoda **Actions > Android > Run workflow** ile derlemeyi başlatın. Bitince çalışma sayfasının altındaki **mesk-apk** dosyasını indirin, içinden `app-release.apk` çıkar ve telefona atıp kurun. `v1.0.0` gibi bir etiket (tag) gönderirseniz APK ayrıca "Releases" sayfasına eklenir.

## Bilgisayarda kendiniz derlemek isterseniz

`android/key.properties` dosyası oluşturun (git bunu zaten yok sayar):

```
storePassword=ŞİFRENİZ
keyPassword=ŞİFRENİZ
keyAlias=mesk
storeFile=/tam/yol/meskkey.jks
```

Sonra `flutter build apk --release` çalıştırın.

## Anahtarı değiştirmek

Telefonda kurulu uygulama başka bir anahtarla imzalıysa yeni APK üstüne kurulmaz. Anahtarı değiştirirseniz sırayla şunu yapın:

1. Meşk içinden **yedek alın** ve yedek dosyasını telefon dışına (Drive, e-posta vb.) kaydedin.
2. Eski uygulamayı **kaldırın**.
3. Yeni imzalı APK'yı **kurun**.
4. Uygulamada yedeği **geri yükleyin**.

Yedek almadan kaldırırsanız veriler silinir.
