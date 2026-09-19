# 街道靈魂測驗 · Street Soul Quiz

> A 16-personality quiz that helps people see how their everyday relationship with streets connects to a broader transportation transformation agenda.
> 一場關於你、街道、與這座城市的測驗。

[![Live](https://img.shields.io/badge/Live-streetsoul.tw-C8D400?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-CC%20BY--SA%204.0-1A1A1A?style=flat-square)](LICENSE)
[![VZT](https://img.shields.io/badge/Vision%20Zero%20Taiwan-2026-1A1A1A?style=flat-square)](https://visionzero.tw)
[![TCAN](https://img.shields.io/badge/TCAN-Climate%20Action-1A1A1A?style=flat-square)](#)

---

## 🚦 這是什麼

一個用「16 型人格測驗」包裝的交通倡議互動網頁。透過 12 道題目，把使用者分入 16 種「街道靈魂」，並對應到《雙零交通願景自治條例》的五大訴求。

每個人都有自己跟街道的關係 — 我們希望讓那份關係，成為改變的起點。

由 **Vision Zero Taiwan（還路於民行人路權促進會）** 與 **TCAN（台灣氣候行動網路）** 共同推出，作為 2026 地方選舉政策倡議的一環。

---

## 🌐 線上體驗

- **測驗網站**：[https://你的網域/](#) ← 部署後填入
- **世界街道靈魂地圖**：[https://你的網域/world.html](#) ← 全世界參與者的分布與世界牆
- **統計儀表板**：[https://你的網域/dashboard.html](#)
- **嵌入版本**：`/dashboard.html?embed=1`（可用 iframe 嵌入）
- **版面預覽**：`/world.html?demo=1`（用示範資料看版面，會有明顯的假資料標示）

---

## 📂 檔案結構

```
.
├── index.html          # 測驗主網頁
├── world.html          # 世界街道靈魂地圖 + 世界牆
├── dashboard.html      # 即時統計儀表板（讀 Google Sheet CSV）
├── moderate.html       # 世界牆審核台（內部用，noindex）
├── config.js           # ★ 唯一需要填設定的檔案
├── supa.js             # 世界牆的資料層（直接打 Supabase REST，不載入 supabase-js）
├── supabase/
│   └── migrations/     # 世界牆的資料表、RLS、RPC（可審視的 SQL）
├── README.md           # 本文件
├── LICENSE             # CC BY-SA 4.0
└── .nojekyll           # GitHub Pages 設定（避免 Jekyll 處理）
```

---

## 🛠️ 技術概覽

純前端網頁，無建構流程、無 npm 依賴：

- **HTML / CSS / Vanilla JS** — 無框架，2 秒內載入
- **html2canvas** — 結果頁產生 IG 比例分享圖卡（CDN 引入）
- **Google Apps Script** — 接收測驗結果，寫入 Google Sheet（fire-and-forget webhook）
- **Google Sheet CSV** — 儀表板與世界地圖的資料源，每 60 秒自動更新
- **Supabase（Postgres）** — 只有「世界牆」用它：使用者主動勾選公開的打卡。
  前端不載入 supabase-js，直接打 PostgREST；權限完全靠 RLS 與 column-level grant
- **內嵌世界底圖** — `world.html` 的海岸線是 Natural Earth 資料預先轉成的 SVG path，
  直接寫在檔案裡，**不需要任何地圖函式庫或 CDN**，CDN 掛掉也不會破版

整個系統的後端就是一份 Google 試算表。便宜、簡單、可審視。

### 世界地圖怎麼避免說錯話

`world.html` 會自動從資料生出一句跨國比較的結論（例如「在荷蘭 78% 的人偏向『漫』，
在韓國只有 26%」）。為了避免小樣本生出誤導性的數字，這句話要同時通過三關才會出現：

1. 兩邊的樣本數都 ≥ `INSIGHT_MIN`（預設 30）
2. 兩比例 z 檢定 z ≥ 1.96（雙尾 p < .05）
3. 差距至少 8 個百分點

任何一關沒過，就顯示「資料還在累積中」而不是硬掰一個結論。
各國卡片的樣本數低於 `MIN_SAMPLE`（預設 20）時會淡化顯示、不給結論，但仍然計入總數。

### 世界牆是怎麼保護使用者的

測驗本體是匿名的；世界牆是**唯一**會把資料連到「某個人」的地方，所以整套設計都繞著這件事：

- **opt-in，預設關閉。** 結果頁的勾選框預設不勾，不勾就一個位元組都不會送出。
- **未滿 18 歲不收名字。** 前端根本不把 `nickname` 放進 payload，名字不會離開那台裝置。
- **不碰 IP。** 網站對使用者承諾「不記錄 IP」，所以連防灌水都不用 IP
  （代價：擋不住有心人腳本灌水。真的發生再加 Cloudflare Turnstile + Edge Function）。
- **隨時可以自己撤掉。** 打卡的 id 與 token 存在使用者自己的瀏覽器，
  撤回走 `delete_soul(id, token)`，是真的 `DELETE`，不是標記隱藏。
- **前端拿不到 `owner_token` / `session_id` / `status`。** 這靠 column-level GRANT，
  不是靠前端自律 — 就算有人直接打 REST API 也讀不到。
- **先顯示、後審核。** 送出即上牆，命中過濾規則的暱稱會被清成空白（那筆打卡照樣在，
  只是不顯示名字），不給使用者錯誤訊息，免得變成「怎麼規避」的教學。
  被回報 3 次自動下架，等人工複查。
- **不能留言、不能回覆、不能追蹤。** 牆上只有型態、地點、名字。沒有留言串就幾乎沒有霸凌空間。

---

## 🚀 部署

任何靜態網頁主機都能跑，包含：

- **GitHub Pages**（本 repo 預設）
- Netlify / Vercel / Cloudflare Pages
- 自家網站 / 任何能放 HTML 的地方

部署前需設定：

1. **`SHEET_CSV_URL`**（在 `config.js`）— Google Sheet 發佈成 CSV 的 URL。
   `world.html`、`dashboard.html`、`index.html` 的世界地圖區塊全部讀這一個設定，只要填一次。
   取得方式：試算表 → 檔案 → 共用 → 發布到網路 → 逗號分隔值 (.csv) → 發布。
2. **`SHEET_WEBHOOK_URL`**（在 `index.html`）— Google Apps Script 部署的 webhook URL（寫入用）

3. **`SUPABASE_URL` / `SUPABASE_ANON_KEY`**（在 `config.js`）— 世界牆用。留空就整個關閉。

沒填 `SHEET_CSV_URL` 也不會壞：世界地圖會顯示設定說明，測驗結果頁的世界地圖區塊則整塊隱藏。
沒填 Supabase 也不會壞：結果頁的「加入世界牆」與 world.html 的牆會整塊消失，其他功能照常。

### 世界牆的 Supabase 設定

1. 開一個 Supabase 專案（free 方案即可）。
2. SQL Editor 執行 `supabase/migrations/20260918000000_street_soul_wall.sql`。
3. Settings → API 複製 **Project URL** 與 **anon / publishable key**，填進 `config.js`。
   anon key 本來就是公開的，安全性靠 RLS；**service_role key 絕對不要放進 `config.js`**。
4. 建管理員：Authentication → Users → Add user 建帳號，再到 SQL Editor 執行
   `insert into public.moderators (user_id) values ('<那個帳號的 uid>');`
5. 到 `/moderate.html` 用該帳號登入。

完整設定教學請洽專案維護者。

---

## 🧑‍🎨 16 型街道靈魂

| Code | 動物 | 中文名 | English |
|------|------|-------|---------|
| MECY | 🦉 | 城市觀察家 | The Urban Observer |
| MECI | 🐱 | 街角分享家 | The Corner Connector |
| MESY | 🐢 | 漫遊思考者 | The Wandering Thinker |
| MESI | 🦋 | 散步詩人 | The Stroll Poet |
| MHCY | 🐶 | 鄰里大使 | The Neighborhood Ambassador |
| MHCI | 🐰 | 早市好朋友 | The Market Mingler |
| MHSY | 🐼 | 街道守護者 | The Street Steward |
| MHSI | 🦔 | 黃昏散步家 | The Twilight Stroller |
| RECY | 🦊 | 通勤革新者 | The Commute Innovator |
| RECI | 🐬 | 城市衝浪者 | The City Surfer |
| RESY | 🦅 | 路線設計師 | The Route Architect |
| RESI | 🐎 | 自由騎士 | The Free Rider |
| RHCY | 🐘 | 大眾運輸推手 | The Transit Advocate |
| RHCI | 🐝 | 通勤好夥伴 | The Commute Companion |
| RHSY | 🐜 | 高效規劃師 | The Efficiency Designer |
| RHSI | 🦝 | 通勤忍者 | The Commute Ninja |

---

## 🤝 共同行動

歡迎其他倡議團體 fork、改寫、本地化使用。如果你也想做類似的測驗、用同套設計系統，請聯繫 VZT。

學術引用：
> Vision Zero Taiwan × TCAN (2026). *Street Soul Quiz: A 16-Personality Survey for Urban Mobility Advocacy*. Taipei, Taiwan.

---

## 📜 授權

本專案採 **CC BY-SA 4.0**（創用 CC 姓名標示 — 相同方式分享 4.0 國際）授權。

你可以自由地：
- **分享** — 以任何媒介或格式重製及散布本素材
- **修改** — 重混、轉換並依本素材建立新作品（包括商業性使用）

惟需遵守：
- **姓名標示** — 標示原作者與授權條款
- **相同方式分享** — 改作品需採用相同授權

---

## 🌿 由誰製作

- **發起**：Vision Zero Taiwan（社團法人還路於民行人路權促進會）
- **發起**：TCAN（台灣氣候行動網路）
- **整理製作**：Yun Ching Wu

地圖底圖：[Natural Earth](https://www.naturalearthdata.com/)（public domain），
經 [world-atlas](https://github.com/topojson/world-atlas)（ISC）轉出。

街道安全 ✦ 氣候行動 ✦ 一起來

— V1.0 · May 2026
