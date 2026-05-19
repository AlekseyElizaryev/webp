# Публикация WebPViewer в Mac App Store

## Что уже готово в проекте

- иконка: `Resources/icon.icns`
- Info.plist (категория `public.app-category.photography`, версия 1.0.0)
- entitlements: `Resources/WebPViewer.entitlements` (sandbox + Pictures + Downloads + bookmarks)
- `dist.sh` — финальная сборка с Apple Distribution и упаковка в `.pkg`
- Сертификаты в keychain: `Apple Distribution: INFOKOM, LLC` + `3rd Party Mac Developer Installer: INFOKOM, LLC`

## Ручные шаги (один раз)

### 1. App ID

Зайти: <https://developer.apple.com/account/resources/identifiers>
→ **+** → App IDs → App

| Поле | Значение |
|---|---|
| Description | `WebPViewer` |
| Bundle ID (explicit) | `llc.infokom.WebPViewer` |
| Capabilities | ничего отмечать не надо |

### 2. Provisioning profile

Зайти: <https://developer.apple.com/account/resources/profiles>
→ **+** → Distribution → **Mac App Store**

- App ID: `llc.infokom.WebPViewer`
- Certificate: `Apple Distribution: INFOKOM, LLC (KJHKLWA456)`

Скачать и положить в корень проекта как `embedded.provisionprofile`.

### 3. Запись приложения в App Store Connect

Зайти: <https://appstoreconnect.apple.com/apps> → **+** → New App

| Поле | Значение |
|---|---|
| Platform | macOS |
| Name | WebPViewer (или твоё) |
| Bundle ID | `llc.infokom.WebPViewer` |
| SKU | `webpviewer` |
| Primary language | English (или Russian) |

### 4. App-Specific Password (для загрузки .pkg)

Зайти: <https://appleid.apple.com> → Sign-In and Security → App-Specific Passwords → **+**.
Сохранить в надёжное место.

## Каждый релиз

### 1. Поднять билд-номер

`CFBundleVersion` в `Resources/Info.plist` должен расти при каждой загрузке в App Store. Версия `CFBundleShortVersionString` меняется по желанию.

```
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion <N>" Resources/Info.plist
```

### 2. Собрать .pkg

```
./dist.sh
```

На выходе: `WebPViewer.pkg`, подписанный installer-сертификатом.

### 3. Загрузить

Способ A — командная строка:
```
xcrun altool --upload-app -f WebPViewer.pkg -t macos \
    --apple-id <твой-apple-id> \
    --password <app-specific-password>
```

Способ Б — приложение `Transporter` из Mac App Store (drag&drop `.pkg`).

### 4. Заполнить метаданные в App Store Connect

Минимально нужно:
- описание приложения
- 1–10 скриншотов, минимум 1280×800
- ключевые слова (через запятую)
- URL службы поддержки
- URL политики конфиденциальности (обязательно, даже если данных не собираешь)
- возрастной рейтинг (для нашего случая — 4+)
- цена (Free или платно)

### 5. Submit for Review

Кнопка `Submit for Review` в App Store Connect. Ревью обычно 1–3 дня.

## Скриншоты

Минимум 1280×800. Удобно делать так:

1. Запустить приложение, открыть какую-нибудь картинку
2. ⇧⌘4 → пробел → клик по окну WebPViewer
3. Файл попадёт на Рабочий стол

Желательно 3–5 штук: главное окно, сайдбар с открытой папкой, fullscreen.

## Полезные проверки

```bash
# Что подписано в бандле
codesign -d --entitlements - WebPViewer.app

# Содержимое .pkg, не устанавливая
pkgutil --expand WebPViewer.pkg /tmp/pkg-expanded
ls /tmp/pkg-expanded
rm -rf /tmp/pkg-expanded

# Локальная установка для теста
sudo installer -pkg WebPViewer.pkg -target /
```

## Если ревью отклонили

Чаще всего:
- нет URL политики конфиденциальности → добавить в Connect
- скриншоты не отражают реальный UI → пересоздать
- что-то крашится в sandbox → проверить логи `Console.app` → app: `WebPViewer`

После правок — `Submit for Review` снова, билд-номер тот же.
