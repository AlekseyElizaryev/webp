# Submission в App Store — пошаговая инструкция

Все шаги выполняются на <https://appstoreconnect.apple.com> → твоё приложение **WebPViewer**.

Готовые тексты для копирования — в разделе [Тексты для полей](#тексты-для-полей) в конце.

---

## Шаг 1. Перейти в раздел App Store

Вверху карточки приложения переключи вкладку с **TestFlight** на **App Store** (на маке может называться **Distribution**).

Слева ищи блок **macOS App** → **1.0 Prepare for Submission**.
Если версии ещё нет, нажми **+ Version or Platform** и выбери **macOS**, версия `1.0.0`.

---

## Шаг 2. Заполнить App Information (общая инфа для всех версий)

| Поле | Значение |
|---|---|
| **Name** | `WebPViewer` |
| **Subtitle** | `Native WebP image viewer` |
| **Privacy Policy URL** | URL странички — см. [шаг 4](#шаг-4-privacy-policy-url) |
| **Category — Primary** | `Photo & Video` |
| **Category — Secondary** | пусто |
| **Content Rights** | `No, it doesn't contain third-party content` |

---

## Шаг 3. Заполнить Version 1.0

Поля на странице конкретной версии:

| Поле | Что писать |
|---|---|
| **Promotional Text** | См. [Promo Text](#promotional-text) — до 170 символов, можно менять без ревью |
| **Description** | См. [Description](#description) — до 4000 символов |
| **Keywords** | См. [Keywords](#keywords) — до 100 символов через запятую |
| **Support URL** | твой email или GitHub репозиторий: `mailto:aleksey.elizaryev@gmail.com` или `https://github.com/…` |
| **Marketing URL** | пусто |
| **Version** | `1.0.0` (заполняется автоматом из Info.plist) |
| **Copyright** | `2026 INFOKOM, LLC` |

---

## Шаг 4. Privacy Policy URL

Apple требует URL, даже если приложение не собирает данных. Самый простой путь — GitHub Pages.

### Вариант A. GitHub Pages

1. Создай публичный репозиторий `infokom/webpviewer-privacy`
2. Внутри один файл `index.html` с содержимым из раздела [Privacy Policy HTML](#privacy-policy-html) ниже
3. В Settings → Pages → выбрать `main / root` → Save
4. Через 1–2 минуты страница доступна по адресу:
   `https://infokom.github.io/webpviewer-privacy/`
5. Этот URL вставь в поле **Privacy Policy URL**

### Вариант B. Notion / Google Sites

Сделать публичную страничку с тем же текстом. URL должен быть стабильный и не требовать входа.

---

## Шаг 5. Загрузить скриншоты

В блоке **App Previews and Screenshots**:

- Размер: **1280×800**, 1440×900, 2560×1600 или 2880×1800 (PNG или JPEG, RGB)
- Минимум 1, рекомендуется 3–5

### Как сделать на этой машине

```
# 1. Запустить приложение, открыть картинку
open -a ~/webp/WebPViewer.app ~/webp/samples/lossy.webp

# 2. Сделать снимок окна: ⇧⌘4 → пробел → клик по окну
# Файлы попадут на Рабочий стол как Screenshot YYYY-MM-DD at HH-MM-SS.png
```

Идеи для разных скриншотов:
- Главное окно с открытой картинкой (показывает основной UI)
- С развёрнутым сайдбаром и кнопкой `+ Add Folder…`
- С активной плёнкой миниатюр
- Fullscreen с большим изображением
- Окно после `1:1` (видно как работает зум)

Загружай в Connect drag&drop.

---

## Шаг 6. App Privacy

Слева на странице приложения → **App Privacy** → **Get Started**.

На вопрос «Does this app collect data?» — **No, we do not collect data from this app** → **Publish**.

---

## Шаг 7. Pricing and Availability

Слева → **Pricing and Availability**:

| Поле | Значение |
|---|---|
| **Price** | `Free (Tier 0)` (или цена) |
| **Availability** | All Countries and Regions (или ограничить) |
| **App Distribution Methods** | только **Public on the App Store** |

**Save**.

---

## Шаг 8. Прикрепить билд

Вернись на страницу версии 1.0, прокрути до блока **Build** → **+** → выбери из списка тот билд, который залил через Transporter (например `1.0.0 (1)`).

---

## Шаг 9. App Review Information

Внизу страницы версии:

| Поле | Значение |
|---|---|
| **Sign-In Required** | `No` |
| **First Name** | `Aleksey` |
| **Last Name** | `Elizaryev` |
| **Phone** | твой телефон |
| **Email** | `aleksey.elizaryev@gmail.com` |
| **Notes** | См. [Review Notes](#app-review-notes) ниже |

---

## Шаг 10. Version Release

Прокрути до **Version Release**:

- **Manually release this version** — рекомендую для первой публикации, чтобы контролировать момент запуска
- Альтернатива: **Automatically release this version** — после Approved приложение опубликуется сразу

---

## Шаг 11. Save → Add for Review → Submit

1. **Save** (сверху справа) — сохраняет всё заполненное
2. **Add for Review** — переход к Submit
3. На Submit-странице ответы на три вопроса:

| Вопрос | Ответ |
|---|---|
| **Export Compliance — Does your app use encryption?** | `No` (у нас в Info.plist уже стоит `ITSAppUsesNonExemptEncryption = false`, вопрос может вообще не появиться) |
| **Content Rights** | `No` |
| **Advertising Identifier (IDFA)** | `No` |

4. **Submit for Review**

---

## Что дальше

| Статус | Что делать |
|---|---|
| **Waiting for Review** | Ничего, ждать. Обычно 1–24 часа. |
| **In Review** | Apple проверяет. ~2–6 часов. |
| **Approved** | Если выбрал Manual — жми **Release This Version**. Если Automatic — через 1–2 часа в Store. |
| **Rejected** | В **Resolution Center** (значок чата) напишут что не так. Чинишь, поднимаешь `CFBundleVersion`, заливаешь, прикрепляешь, **Resubmit**. |
| **Metadata Rejected** | Поправь описание/скриншоты, перезаливать билд не нужно. |

---

## Тексты для полей

### Promotional Text

> Open WebP images natively on your Mac. Browse folders, thumbnails, zoom, rotate — all the basics, no fuss.

(166 символов)

---

### Description

> WebPViewer is a fast, native macOS app for opening WebP images. Double-click a .webp file in Finder or drag it onto the window, and your image opens instantly — no browser, no online converter, no slowdowns.
>
> Key features:
> • Open WebP, PNG, JPEG, GIF, BMP, TIFF, and HEIC images.
> • Folder sidebar — browse Pictures, Downloads, or add any folder of your own.
> • Keyboard navigation — arrow keys to flip through a folder.
> • Thumbnail strip — see neighboring images at a glance.
> • Zoom, rotate, fit-to-window, fullscreen.
> • Compatible with macOS Catalina (10.15) and newer.
>
> WebPViewer doesn't collect any user data. It runs entirely on your Mac.

---

### Keywords

> webp,image,viewer,photo,picture,gallery,thumbnail,fast,native,viewer

(64 символов из 100)

---

### App Review Notes

> WebPViewer is a simple image viewer. To test:
> 1. Open the app — the sidebar shows Pictures and Downloads by default.
> 2. Click "+ Add Folder…" to grant access to any folder.
> 3. Click an image in the thumbnail strip or use ←/→ arrow keys to navigate.
> 4. Drag any .webp file onto the window or open via File → Open (⌘O).
>
> No login or account required. The app does not access the network.

---

### Privacy Policy HTML

Содержимое `index.html` для странички политики конфиденциальности (например, через GitHub Pages):

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>WebPViewer Privacy Policy</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
               max-width: 720px; margin: 40px auto; padding: 0 20px;
               line-height: 1.6; color: #222; }
        h1 { border-bottom: 1px solid #ddd; padding-bottom: 8px; }
        .meta { color: #888; font-size: 13px; }
    </style>
</head>
<body>
<h1>WebPViewer — Privacy Policy</h1>
<p class="meta">Effective date: May 18, 2026</p>

<p>WebPViewer ("the app") is developed and operated by INFOKOM, LLC. This privacy policy explains how the app handles user information.</p>

<h2>Data we collect</h2>
<p><strong>None.</strong> WebPViewer does not collect, transmit, store, or share any personal information, usage statistics, telemetry, or analytics data. The app runs entirely on your Mac and does not communicate with any servers.</p>

<h2>File access</h2>
<p>WebPViewer can read image files that the user explicitly opens or grants access to via the system folder picker. Granted folder access is stored locally as a macOS security-scoped bookmark in the app's own sandbox container. It is never transmitted off the device.</p>

<h2>Third-party services</h2>
<p>The app does not use any third-party analytics, crash reporting, or advertising services.</p>

<h2>Children's privacy</h2>
<p>The app is suitable for all ages and does not collect any information from children.</p>

<h2>Changes</h2>
<p>Any updates to this policy will be published at this URL.</p>

<h2>Contact</h2>
<p>For questions, please contact <a href="mailto:aleksey.elizaryev@gmail.com">aleksey.elizaryev@gmail.com</a>.</p>
</body>
</html>
```

---

## Чек-лист перед Submit

- [ ] `CFBundleVersion` в `Info.plist` уникален (больше предыдущих загруженных билдов)
- [ ] `./dist.sh` отработал, `WebPViewer.pkg` залит через Transporter, прошёл валидацию
- [ ] Билд прикреплён к Version 1.0.0
- [ ] App Information: Name, Subtitle, Privacy URL, Category заполнены
- [ ] Version 1.0 page: Description, Keywords, Promo Text, Support URL, Copyright заполнены
- [ ] Минимум 1 скриншот ≥1280×800 загружен
- [ ] App Privacy → No collection → Published
- [ ] Pricing and Availability → Save
- [ ] App Review Information заполнено (имя, email, заметки)
- [ ] Version Release: выбран режим (Manual / Automatic)
- [ ] Privacy Policy URL открывается в браузере без логина

После этого: **Save → Add for Review → Submit for Review**.

---

## Самые частые причины Rejected

1. **Privacy Policy URL** недоступен или ведёт не туда → проверь что страница реально открывается
2. **Скриншоты не отражают приложение** (например, заглушки или из другой версии) → пересними
3. **Краш при первом запуске** в sandbox-окружении → перед сабмитом запусти билд из TestFlight у себя на маке, убедись что не падает с чистого старта
4. **Несоответствие описания и UI** (обещание функций, которых нет) → сверить description с реальностью
5. **Demo account нужен, но не указан** → у нас нет логина, не наш случай

При rejected: исправляешь, поднимаешь `CFBundleVersion` (только если требует новый билд), сабмитишь снова. Метаданные правишь без перезаливки бинаря.
