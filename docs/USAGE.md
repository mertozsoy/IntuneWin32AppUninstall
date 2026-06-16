# Kullanım Kılavuzu

## Başlamadan Önce

⚠️ **Önemli:** 
- PowerShell'i **Yönetici olarak** açmanız gerekir
- Script'i çalıştırmadan önce sisteminizi yedekleyin
- Sistem Restore Point oluşturun

## Temel Kullanım

### 1. PowerShell'i Yönetici Olarak Açın

**Windows 10/11:**
1. Başlat Menüsü'nü açın
2. "PowerShell" yazın
3. "Windows PowerShell" seçin
4. Sağ tıklayıp "Yönetici olarak çalıştır" seçin

**Windows 7:**
1. Başlat → Tüm Programlar → Aksesorlar → Windows PowerShell
2. PowerShell'e sağ tıklayıp "Yönetici olarak çalıştır" seçin

### 2. Script'in Dizinine Gidin

```powershell
# Örnek:
cd C:\Users\YourName\Downloads\AtaUninstallPack
```

### 3. Script'i Çalıştırın

```powershell
.\AtaUninstallPack.ps1
```

veya

```powershell
.\AtaUninstallPackv2.ps1
```

## Ekrandaki Menü

Script açıldığında şu adımları yapacaksınız:

### Adım 1: Yüklü Programları Görüntüleme

Sisteminizde yüklü tüm programların listesi gösterilecek:

```
1. Adobe Reader
2. Google Chrome
3. Spotify
4. ...
```

### Adım 2: Program Seçimi

Kaldırmak istediğiniz programın numarasını girin:

```
Kaldırmak istediğiniz programın numarasını seçin: 2
```

### Adım 3: Onay

Seçimi onaylamanız istenecek:

```
Google Chrome'u kaldırmak üzeresiniz. Emin misiniz? (Y/N): Y
```

### Adım 4: İşlem Başlıyor

Script başlayacaktır:
- Registry temizliği
- Dosya silme
- Kalıntıları kaldırma

İşlem bitmesini bekleyin.

## İşlem Örnekleri

### Örnek 1: Google Chrome'u Kaldırma

```powershell
# Script'i çalıştırın
.\AtaUninstallPack.ps1

# Menüden Chrome seçin
Kaldırmak istediğiniz programın numarasını seçin: 2

# Onaylayın
Google Chrome'u kaldırmak üzeresiniz. Emin misiniz? (Y/N): Y

# İşlem başladı
[1/3] Uninstall start...
[2/3] Registry cleanup...
[3/3] Temporary files...

# Tamamlandı
Uninstall process completed successfully!
```

### Örnek 2: Birden Fazla Program Kaldırma

```powershell
# İlk programı kaldırın
# Script tamamlandığında, tekrar çalıştırabilirsiniz
.\AtaUninstallPack.ps1

# İkinci program için tekrarlayın
```

## İleri Özellikler

### Dosyaları Loglanması

Script sonuçlarını dosyaya kaydedin:

```powershell
.\AtaUninstallPack.ps1 | Out-File -FilePath "uninstall_log.txt"
```

### Test Modu (WhatIf)

Aslında kaldırmadan sadece neyi yapacağını görmek için:

```powershell
.\AtaUninstallPack.ps1 -WhatIf
```

### Verbose Mode (Ayrıntılı)

Detaylı bilgiler için:

```powershell
.\AtaUninstallPack.ps1 -Verbose
```

## Başarılı Kaldırma İşaretleri

Kaldırma başarılıysa:
- ✅ Program Kaldır programında gözükmez
- ✅ Program dosyaları silinir
- ✅ Registry girdileri temizlenir
- ✅ Başlat Menüsü'nde görünmez
- ✅ Masaüstü kısayolu silinir

## Kaldırma Başarısız Olursa

### Sorun: "Dosya Kullanımda" Hatası

**Neden:** Program veya bağımlı yazılım çalışıyor

**Çözüm:**
```powershell
# 1. Programı kapatın
# 2. İlişkili programları kapatın (örn: antivirus)
# 3. Sistem Restore Point kullanarak geri dönün
Restore-Computer -RestorePoint (Get-ComputerRestorePoint | Select -Last 1)
```

### Sorun: "Erişim Reddedildi"

**Neden:** Yeterli yetki yok

**Çözüm:**
```powershell
# PowerShell'i tam yönetici yetkisi ile açın
# Sağ tıklayıp "Yönetici olarak çalıştır"
```

### Sorun: "Program Hala Yüklü"

**Neden:** Registry temizliği eksik

**Çözüm:**
```powershell
# İşlemi manuel olarak tamamlayın
# Bilgisayarı yeniden başlatın
# Kontrol Paneli → Programlar → Programları Kaldır'dan kontrol edin
```

## Sistem Geri Yükleme

Kaldırma başarısız olursa veya sorun oluşursa:

### Yöntem 1: Restore Point Kullanma

```powershell
# Restore Points'i listele
Get-ComputerRestorePoint

# Geri dön
Restore-Computer -RestorePoint (Get-ComputerRestorePoint | Where-Object {$_.Description -eq "AtaUninstallPack kurulu"})
```

### Yöntem 2: Manual İşlemler

1. **Control Panel'den Yeniden Yükle:**
   - Settings → Apps → Apps & Features
   - Programı bulun ve reinstall yapın

2. **Registry Geri Yükle:**
   - Registry Editor açın (regedit)
   - HKEY_LOCAL_MACHINE\Software'te bulun
   - Restore Point'ten geri yükle

## En İyi Uygulamalar

### ✅ YAPIN:

1. **Önemli Verilerinizi Yedekleyin**
   ```powershell
   # Örnek: Masaüstünü yedekle
   Copy-Item -Path $env:USERPROFILE\Desktop -Destination "D:\Backup\Desktop" -Recurse
   ```

2. **Sistem Restore Point Oluşturun**
   ```powershell
   Checkpoint-Computer -Description "Before AtaUninstallPack"
   ```

3. **Bir Programla Başlayın**
   - İlk olarak önemli olmayan bir program seçin
   - Başarılıysa devam edin

4. **İşlem Sonrası Bilgisayarı Yeniden Başlatın**
   ```powershell
   Restart-Computer -Force
   ```

### ❌ YAPMAYINIZ:

1. Sistem kritik programlarını kaldırmayın
2. Bilinmeyen programları kaldırmayın
3. Script çalışırken bilgisayarı kapatmayın
4. Birbirinden bağımlı programları aynı anda kaldırmayın
5. Antivirus programını devre dışı bırakmadan kaldırma yapmayın

## Komut Örnekleri Koleksiyonu

### Tüm Programları Listele

```powershell
# Yüklü programları göster
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
Select-Object DisplayName, DisplayVersion, InstallDate | 
Format-Table -AutoSize
```

### Belirli Bir Programı Ara

```powershell
# Chrome'u ara
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
Where-Object {$_.DisplayName -like "*Chrome*"} | 
Select-Object DisplayName, DisplayVersion
```

### Registry'de Temizlik

```powershell
# ÖNEMLİ: Bakup alınması önerilir
# Belirli bir program için Registry temizle
Remove-Item -Path "HKCU:\Software\Google\Chrome" -Recurse -Force
```

## Sıkça Sorulan Sorular (SSS)

### S: Script'i nasıl durdurabilirim?
**C:** `Ctrl + C` tuşlarına basın

### S: Kaldırma işlemi ne kadar zaman alır?
**C:** Genelde 2-5 dakika, program boyutuna bağlı

### S: Birden fazla program aynı anda kaldırabilir miyim?
**C:** Hayır, tek tek kaldırmanız önerilir

### S: Windows'u başlatmak için ne kadar da yeniden başlatılması gerekir?
**C:** Programı kaldırdıktan sonra yeniden başlatma önerilir

### S: Silinen dosyalar geri getirilebilir mi?
**C:** Dosya kurtarma yazılımı (Recuva vb.) kullanarak kısmen geri getirilebilir

## Desteği Bildir

Sorun yaşıyorsanız:
1. Bu kılavuzu tekrar okuyun
2. README.md'yi kontrol edin
3. [Issues](https://github.com/mertozsoy/AtaUninstallPack/issues) sayfasında arayın
4. Yeni bir issue açın (hata, log, sistem bilgisi ile birlikte)

---

**İyi Şanslar!** 🎯
