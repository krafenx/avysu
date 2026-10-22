<div align="center">



# Avysu

**Инструменты управления сетевыми стратегиями для Windows.**
Открытое приложение для Windows, которое возвращает YouTube, Discord и другие сервисы —
без VPN, без серверов и без подписок.



</div>

[Русский](#русский) · [English](#english)

## Русский

## Что это

Avysu — оболочка на Rust над проверенными движками обхода DPI
[zapret2 / zapret](https://github.com/bol-van/zapret2) и стратегиями
[Flowseal](https://github.com/Flowseal/zapret-discord-youtube).
Вместо двадцати `.bat`-файлов — одна кнопка.

- **Сам подбирает стратегию.** При первом запуске проверяет, что заблокировано у вашего провайдера,
  перебирает ~30 стратегий (zapret2 на Lua + все стратегии Flowseal) и оставляет лучшую.
- **Следит за работой.** Сторож периодически проверяет доступ и сам переключается,
  если провайдер что-то поменял.
- **Подбор по расписанию.** Раз в сутки (по умолчанию ежедневно в 3:00) перепроверяет все стратегии и переключается,
  только если нашлась лучше. Проспал компьютер — догонит после пробуждения. Можно заодно обновлять движки.
- **Честная проверка.** Тестер не просто ждёт ответа, а докачивает данные —
  так ловится характерная для ТСПУ «заморозка» соединения на ~16 КБ.
- **Всё локально.** Трафик никуда не уходит: пакеты хитро нарезаются прямо на вашем компьютере.
- **Не мешает.** Живёт в трее, стартует вместе с Windows без запросов UAC,
  движок завершается вместе с приложением (Job Object) — никаких «висящих» winws.
- **Видит конфликты.** Находит запущенные службы zapret/GoodbyeDPI и предлагает их остановить.
- **Обновляется.** Во время сборки и по команде приложения загружаются последние релизы zapret2, Flowseal и WinDivert. Архивы проверяются по SHA-256 из GitHub API; если digest не опубликован, обновление отменяется, кроме заранее проверенного WinDivert 2.2.2. Свои списки сохраняются.
- **Открывает ИИ.** Gemini, AI Studio, NotebookLM, ChatGPT, Claude, Grok и Copilot сами не пускают
  пользователей из России — это геоблок, а не РКН, и zapret его не снимает. Avysu включает «умный DNS»
  (Comss / GeoHide, без Xbox DNS): только эти домены идут через зарубежный прозрачный прокси,
  переписка остаётся зашифрованной (TLS), прокси видит лишь имя сайта.

## Установка

Скачайте установщик `Avysu_*_x64-setup.exe` из [последнего релиза](https://github.com/krafenx/avysu/releases) и запустите. Рядом с установщиком опубликован `SHA256SUMS.txt` для проверки контрольной суммы SHA-256.

В PowerShell хэш можно сверить командой `Get-FileHash .\Avysu_*_x64-setup.exe -Algorithm SHA256`.

> Microsoft Defender считает движок winws «HackTool» — это ложное срабатывание, так помечают
> все инструменты обхода DPI. Avysu при первом запуске предложит добавить исключение.

## Сборка из исходников

Нужны: Windows 10/11 x64, Rust stable с MSVC toolchain и Node.js 22. Установщик собирается на GitHub Actions после публикации GitHub Release; workflow загружает и проверяет SHA-256 официальные движки, собирает NSIS-установщик и добавляет его с SHA-256 в релиз. Для выпуска обновите номер версии в `package.json`, `src-tauri/tauri.conf.json` и `src-tauri/Cargo.toml`, затем создайте и опубликуйте GitHub Release с тегом этой версии, например `v0.1.1`. Уже опубликованный релиз можно собрать вручную через Actions, указав его тег.

```powershell
npm ci
npm run engine      # загрузить последние официальные релизы и проверить SHA-256
npm run build       # установщик: src-tauri/target/release/bundle/nsis/
```

Для разработки интерфейса Tauri не нужен: откройте `ui/index.html` через любой локальный
сервер — подключится мок бэкенда. Состояния переключаются через адрес:
`index.html#dark&run`, `#light&page=strategies`, `#dark&page=settings&bottom`, `#dark&onb=0`.

## Ссылки

[Исходный код на GitHub](https://github.com/krafenx/avysu) · [Telegram](https://t.me/avysu)

Тесты (включая прогон **всех** стратегий через `winws --dry-run`):

```powershell
cd src-tauri; cargo test
```

## Как устроено

```
ui/                    интерфейс Avysu: панель управления на HTML/CSS/JS без сборщика
src-tauri/src/
  controller.rs        включение, автоподбор, сторож, расписание
  schedule.rs          подбор по расписанию: местное время, окно догонки
  strategy.rs          стратегии zapret2 + разбор .bat от Flowseal на лету
  engine.rs            запуск winws/winws2 в Job Object, журнал
  tester.rs            проверка YouTube / Discord / Google / Cloudflare
  system.rs            конфликты, автозапуск, Defender, TCP timestamps
  aidns.rs             разблокировка ИИ: локальный DNS + NRPT + DoH к умным DNS
  updater.rs           обновление движков из релизов GitHub
scripts/               загрузка движков, генерация иконок и картинок установщика
```

Данные хранятся в `%LOCALAPPDATA%\Avysu`: движки, списки, настройки и `avysu.log`.

### Разблокировка ИИ

Avysu поднимает DNS-сервер на `127.0.0.153:53` и через правила NRPT Windows направляет к нему
**только** домены ИИ-сервисов. Сервер спрашивает умный DNS по DoH (с переключением на запасной провайдер),
а записи AAAA и HTTPS гасит, чтобы браузер не ушёл напрямую по IPv6. Правила снимаются при выходе
и чистятся при следующем запуске, если приложение завершилось аварийно.

VPN-клиенты в TUN-режиме (sing-box, Throne, Happ…) перехватывают весь DNS — Avysu это замечает
и подсказывает: с включённым VPN разблокировка не нужна.

Диагностика: `AVYSU_DOH_PROXY=http://user:pass@host:port` — пустить DoH через прокси,
`AVYSU_AI_PORT=5454` — поднять сервер на другом порту и опрашивать его вручную.

## Благодарности

Вся магия обхода — заслуга [bol-van](https://github.com/bol-van) и
[Flowseal](https://github.com/Flowseal). Полный список компонентов и лицензий — в
[THIRD_PARTY.md](THIRD_PARTY.md).

## Лицензия

[MIT](LICENSE)

---

## English

**Network strategy management tools for Windows.**
Avysu is an open-source Windows application that helps restore access to YouTube, Discord, and other services—without a VPN, servers, or subscriptions.

### What it does

Avysu is a Rust application built around the established DPI circumvention engines
[zapret2 / zapret](https://github.com/bol-van/zapret2) and strategies from
[Flowseal](https://github.com/Flowseal/zapret-discord-youtube).

- **Finds a working strategy.** On first run, it checks which services are blocked by your ISP, tests around 30 strategies (zapret2 Lua strategies and Flowseal strategies), and selects the best one.
- **Monitors the connection.** A watchdog periodically checks service availability and switches strategies if your ISP changes its filtering.
- **Can re-test on a schedule.** By default, it checks all strategies daily at 03:00 and switches only when it finds a better one. If the computer was asleep, it catches up after waking. Engine updates can be enabled alongside scheduled checks.
- **Checks actual data transfer.** The tester downloads data instead of merely waiting for a response, which helps detect the roughly 16 KB connection stalls associated with Russian TSPU filtering.
- **Runs locally.** Traffic is not sent to Avysu servers; packet fragmentation is performed on your computer.
- **Stays out of the way.** Avysu lives in the system tray, can start with Windows without a UAC prompt, and stops its engine when the app exits (using a Windows Job Object).
- **Detects conflicts.** It finds running zapret and GoodbyeDPI services and offers to stop them.
- **Updates engines.** During builds and on demand, Avysu downloads the latest zapret2, Flowseal, and WinDivert releases. Archives are checked against SHA-256 digests from the GitHub API. An update is cancelled if a digest is unavailable, except for the pre-verified WinDivert 2.2.2 package. Your lists are preserved.
- **Provides access to AI services.** Gemini, AI Studio, NotebookLM, ChatGPT, Claude, Grok, and Copilot may restrict users in Russia due to geo-blocking, which DPI circumvention does not remove. Avysu offers Smart DNS (Comss / GeoHide, excluding Xbox DNS): only these domains use a foreign transparent proxy. Traffic remains encrypted with TLS; the proxy can see only the requested site name.

### Installation

Download `Avysu_*_x64-setup.exe` from the [latest release](https://github.com/krafenx/avysu/releases) and run it. A `SHA256SUMS.txt` file is published alongside the installer so you can verify its SHA-256 checksum.

In PowerShell, verify the checksum with:

```powershell
Get-FileHash .\Avysu_*_x64-setup.exe -Algorithm SHA256
```

> Microsoft Defender may flag the `winws` engine as “HackTool.” This is a false positive commonly associated with DPI circumvention tools. Avysu offers to add an exclusion on first launch.

### Build from source

Requirements: Windows 10/11 x64, Rust stable with the MSVC toolchain, and Node.js 22. GitHub Actions builds the installer after a GitHub Release is published. The workflow downloads official engine releases, verifies their SHA-256 digests, builds the NSIS installer, and adds it and its checksum to the release. To make a release, update the version in `package.json`, `src-tauri/tauri.conf.json`, and `src-tauri/Cargo.toml`, then create and publish a GitHub Release with a matching version tag, such as `v0.1.1`. An already-published release can be built manually from Actions by providing its tag.

```powershell
npm ci
npm run engine      # download the latest official releases and verify SHA-256
npm run build       # installer: src-tauri/target/release/bundle/nsis/
```

Tauri is not required to work on the interface. Open `ui/index.html` through any local server to use the mock backend. You can switch states through the URL:
`index.html#dark&run`, `#light&page=strategies`, `#dark&page=settings&bottom`, `#dark&onb=0`.

### Links

[Source code on GitHub](https://github.com/krafenx/avysu) · [Telegram](https://t.me/avysu) · [Report a bug or suggest an improvement](https://github.com/krafenx/avysu/issues)

Tests (including a **full dry run of every strategy** using `winws --dry-run`):

```powershell
cd src-tauri; cargo test
```

### How it works

```
ui/                    Avysu interface: HTML/CSS/JS control panel, no bundler
src-tauri/src/
  controller.rs        enable/disable, automatic selection, watchdog, schedule
  schedule.rs          scheduled selection: local time and catch-up window
  strategy.rs          zapret2 strategies and on-the-fly parsing of Flowseal .bat files
  engine.rs            winws/winws2 process management with a Job Object, logging
  tester.rs            YouTube / Discord / Google / Cloudflare checks
  system.rs            conflicts, startup, Defender, TCP timestamps
  aidns.rs             AI-service access: local DNS, NRPT, and DoH to Smart DNS providers
  updater.rs           engine updates from GitHub releases
scripts/               engine downloads, icon generation, and installer images
```

Data is stored in `%LOCALAPPDATA%\Avysu`: engines, lists, settings, and `avysu.log`.

#### AI-service access

Avysu runs a DNS server at `127.0.0.153:53` and uses Windows NRPT rules to direct **only** AI-service domains to it. The server queries Smart DNS over DoH (with fallback to a second provider) and suppresses AAAA and HTTPS records so the browser does not bypass it over IPv6. Rules are removed on exit and cleaned up on the next launch if the app crashed.

VPN clients in TUN mode (sing-box, Throne, Happ, and others) intercept all DNS traffic. Avysu detects this and advises that AI-service unblocking may not be needed while the VPN is active.

Diagnostics: `AVYSU_DOH_PROXY=http://user:pass@host:port` routes DoH through a proxy; `AVYSU_AI_PORT=5454` runs the server on another port so it can be queried manually.

### Acknowledgements

The circumvention engines and strategies are maintained by [bol-van](https://github.com/bol-van) and
[Flowseal](https://github.com/Flowseal). See [THIRD_PARTY.md](THIRD_PARTY.md) for the full list of components and licenses.

### License

[MIT](LICENSE)
