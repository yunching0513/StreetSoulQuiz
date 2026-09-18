# 工作進度交接 · Session Handoff

> 這份檔案是給「下一個對話視窗」用的交接文件，不是公開的專案說明（那是 `README.md`）。
> 在新對話開始時，請先讀這份，就能無縫接續。最後更新：2026-09-18（Phase 0 世界地圖 + **Phase 1 世界牆**；世界牆尚待接上 Supabase 專案）。

---

## ⚠️ 0. 最重要：專案位置與身分（別跟另一個專案搞混）

使用者有**兩個容易混淆**的 Vision Zero Taiwan 街道專案：

| 專案 | 路徑 | 性質 |
|------|------|------|
| **StreetSoulQuiz**（← 就是這個） | `/Users/yunching0513/StreetSoulQuiz` | 靜態 HTML 16 型人格測驗 |
| street-vision | `/Users/yunching0513/202604 - 街道願景專案` | 本地 Next.js 資料視覺化 app（**不要**在這裡做測驗的事） |

- **本專案路徑**：`/Users/yunching0513/StreetSoulQuiz`
- **線上網址**：https://yunching0513.github.io/StreetSoulQuiz/
- **git remote**：`origin` = `yunching0513/StreetSoulQuiz`（使用者的 fork，push 到這）、`upstream` = `Visionzerotaiwan/StreetSoulQuiz`（之後再同步）
- 技術：純 HTML / CSS / vanilla JS，**無 build、無 npm**。所有東西都在單一 `index.html`（約 2700+ 行，全部 inline）。
- 當使用者說「用我自己的」= 指這個 GitHub fork。

---

## ✅ 1. 目前 git 狀態（已上線）

所有工作（前一批 + **日文版三語**）已 commit 並 push 到 `origin/main`，GitHub Pages 已部署，工作區乾淨。

已涵蓋：`index.html`（中／英／日三語、配對好友/幸運兒、雙分享圖卡、可愛音效、地圖連結、小行人、雙齊零正名）、`pedestrian.png`（已追蹤）、`VZT_petition_bilingual.html`、`PROGRESS.md`（本檔）。

**之後要再改 → 照常上線：**
```bash
cd /Users/yunching0513/StreetSoulQuiz
git add -A && git commit -m "..." && git push origin main   # Pages 約 1 分鐘後更新
```

> 待辦：日後把改動同步到 `upstream`（Visionzerotaiwan/StreetSoulQuiz）— 目前先不做。

### 🌐 三語架構（中／英／日）速記
- 語言由 `<body>` 的 class 決定：`zh` / `en` / `ja`。helper `getLang()` 回傳三者之一。
- CSS 互斥隱藏（約 line 320）：`body.zh` 藏 `.en-only,.ja-only`；`body.en` 藏 `.zh-only,.ja-only`；`body.ja` 藏 `.zh-only,.en-only`。
- **靜態/模板**：每組 `.zh-only`/`.en-only` 旁都加一個 `.ja-only` 兄弟元素。
- **資料**：日文走平行物件 `TYPES_JA`／`DEMANDS_JA`／`QUESTIONS_JA`／`TYPE_DEMAND_WHY_JA`（中英原資料沒動）。
- **JS 條件**（圖卡/分享文案）：原本 `isEn ? en : zh` → 改 `const lang=getLang()` + `L(zh,en,ja)` 三選一；`buildBondsCard / downloadShareCard / showImageModal` 都吃 `lang`。
- 語言選擇器與右上角 toggle 都已加「日本語」。
- 新增文案 → 記得補 `.ja-only` + 對應 `_JA` 欄位，並用 Playwright 三語各驗一次（**務必 stub `logToSheet`**）。

---

## ✅ 2. 本 session 完成的八項工作

1. **結果頁配對區塊**：新增「🚶 最佳散步好夥伴」與「🍀 街道幸運兒」兩張配對卡。
   - 函式 `renderBondsSection(code)`；buddy = 翻 social 軸、lucky = 翻全部四軸（皆為互逆配對，16 型都驗過：互相對應、不會配到自己）。
2. **版面位置**：配對區塊移到 **Manifesto 下面**；標題為「在這座城市裡，誰是你的漫步好朋友？」。
3. **分享圖卡產生兩張**（html2canvas，各 1080×1350 @scale2 = 2160×2700）：
   - **Card 1**：原本的街道靈魂卡（不動）。
   - **Card 2**：`buildBondsCard()` — 漫步好夥伴 + 街道幸運兒 + **你最閃閃發光的時刻（天賦 3 項）** + 雙齊零行動起點。
   - 下載走 `downloadShareCard()` → `showImageModal({cards:[card1,card2]})` 雙卡 modal。
4. **可愛音效**：`SFX` 模組（Web Audio API 合成，無音檔）。三角波 + 八度泛音、C 大調五聲音階。各互動有 hook（選語言/開始/答題/上一題/揭曉結果/切分頁），右上角有靜音鈕，狀態存 localStorage `ssq-muted`。
5. **地圖成果連結**：`.atlas-card`，連到 https://visionzerotaiwan.github.io/taiwan-mobility-atlas/ （本次倡議最重要成果），深色底 + lime 光暈。
6. **結果頁順序重排**：類型 → Manifesto → 天賦/成長/行動 → 夢想城市配對 → 誰與你同行(漫步好朋友) → 分享 → 🗺️地圖成果 → 五大訴求 → 延伸閱讀分頁 → 致謝。
7. **第一頁小行人插圖**：intro 標題右側加 `pedestrian.png`（使用者提供的 VZT 吉祥物，2080×1542）。`.intro-hero` flex 排版，手機版（≤560px）改直向堆疊。
8. **雙齊零正名 + 標題改字**：全站「雙零」→「雙齊零」（0 個殘留）；標題「在這座城市裡，誰與你同行？」→「誰是你的漫步好朋友？」。連署頁 `VZT_petition_bilingual.html` 的《雙零交通願景自治條例》也一併改成《雙齊零…》。

---

## 🌍 2.5 社群功能 · Phase 0（2026-09-18 新增）

目標是「讓使用者看見全世界的人」。討論後決定**分階段**做，這次只做 Phase 0：
**不新增任何上傳、不動隱私承諾**，純粹把既有的匿名資料視覺化，先驗證「社群感」這個假設成不成立。

### 這次做了什麼

| 檔案 | 動作 |
|------|------|
| `config.js` | **新檔**。唯一需要填設定的地方：`SHEET_CSV_URL`、`MIN_SAMPLE`、`INSIGHT_MIN` |
| `world.html` | **新檔**。世界街道靈魂地圖，中／英／日三語，讀同一份 Sheet CSV |
| `index.html` | 結果頁在「漫步好朋友」之後新增 `#worldPeek` 區塊 + 載入 `config.js` |
| `dashboard.html` | 改讀 `config.js`（保留舊 fallback），標題列加 🌍 WORLD MAP 連結 |
| `README.md` | 更新檔案結構、部署設定、統計門檻說明 |

### world.html 重點

- **底圖是內嵌的**：Natural Earth 110m 陸塊，用自寫的 TopoJSON 解碼器 + 等距柱狀投影
  預先轉成一條 SVG path（約 35 KB）直接寫在檔案裡。**沒有任何地圖函式庫、沒有 CDN 依賴**。
  換日線用經度 unwrap 處理（否則整塊歐亞非大陸會消失），並用 `<use x="±1000">` 補回捲繞部分。
- **投影**：`projX = (lon+180)/360*1000`、`projY = (90-lat)/180*500`，viewBox `0 18 1000 392`（裁掉南極）。
  國家錨點是各國最大陸塊的形心（從 Natural Earth 算的），HK/SG 因為太小用自己的座標。
- **圓點大小** = `7 + 17*sqrt(n/max)`，標籤有簡易避讓演算法（下→上→右→左，撞到就不畫）。
- **手機**：地圖改橫向捲動（`min-width:680px`），開場自動捲到人最多的地方。
- **`?demo=1`**：用固定 seed 產生假資料預覽版面，**一定會顯示紅色假資料警告橫幅**。
  預設絕對不會出現（使用者以前就把假計數器藏掉過，不要再放假數字）。

### ⚠️ 統計門檻（這是刻意設計，不要隨便拿掉）

「THE POINT」那句跨國比較的結論，要同時通過三關才會顯示：
1. 兩邊樣本 ≥ `INSIGHT_MIN`（30）
2. 兩比例 z 檢定 z ≥ 1.96（雙尾 p < .05）
3. 差距 ≥ 8 個百分點

沒過就顯示「資料還在累積中」。**原因**：第一版沒做檢定時，它產生了「在加拿大 100% 的人是『探』」
這種 n=8 的荒謬結論。這頁的數字會被媒體與政策文件引用，不能出這種包。
各國卡片低於 `MIN_SAMPLE`（20）會淡化 + 不給結論，但仍計入總數。

---

## 🔒 2.6 那三件硬傷 — 已在 Phase 1 處理完（保留紀錄，之後改動別踩回去）

以下是 Phase 1 動手前列出的三件硬傷，**全部已經處理**，這裡保留下來是為了
讓後續改動不要不小心改回原狀：

1. ~~**現在的隱私承諾會被打破。**~~ ✅ 已改掉三語文案，上傳改成 opt-in 預設關閉。
   舊文案在暱稱欄位寫「只儲存在你的瀏覽器，不會上傳」，`demo-sub` 還寫「沒有 IP、沒有上傳」，
   但 `logToSheet()` 其實有送 age/country/city — 那句話當時就已經不準確了。
   現在講的是實話（「不記錄 IP，也不會連到你個人」+「預設只留在你的瀏覽器」），別再改回去。
2. ~~**未成年。**~~ ✅ 未滿 18 歲前端根本不送 `nickname`，牆上顯示「一位朋友」。
3. ~~**三語審核人力。**~~ ✅ Phase 1 沒有自由文字，唯一的風險欄位是 20 字的暱稱，
   而暱稱過濾是語言無關的規則 + 管理者自訂清單，不需要三語人力守著。
   **但 Phase 2 一開留言就會需要**，到時再面對。

Phase 2（自由文字）的既有共識，動手前先讀：留言框用**引導式 prompt 三選一**
（例如「我家門口最需要改變的一件事是＿＿」），不要開放式；不做留言回覆串
（改用 emoji 共鳴）；不做帳號登入。

---

## 🧱 2.7 社群功能 · Phase 1「世界牆」（2026-09-18）

使用者做完測驗後，可以**主動勾選**把自己放上世界牆。測驗本體仍然匿名，
牆是整個網站唯一會把資料連到「某個人」的地方，所以設計全部繞著這件事轉。

### 動手前確認的三個決定

| 題目 | 決定 |
|------|------|
| Supabase | 開一個專用新專案（不跟其他專案混） |
| 審核姿態 | **先顯示 + 自動過濾 + 檢舉 + 一鍵下架**（牆要是活的，志工不用守電腦） |
| 未成年 | **可以打卡，但不收名字**（前端根本不送 nickname 欄位） |

### 檔案

| 檔案 | 內容 |
|------|------|
| `supabase/migrations/20260918000000_street_soul_wall.sql` | 資料表、RLS、column grant、trigger、RPC |
| `supa.js` | 資料層。直接打 PostgREST / GoTrue，**不載入 supabase-js** |
| `moderate.html` | 審核台（登入 → 處理回報/下架/清名字 → 管封鎖字）。已加 `noindex` |
| `index.html` | 結果頁新增 `#wallJoin` opt-in 區塊；隱私文案改成誠實版 |
| `world.html` | 新增 `#wall` 世界牆區塊（全部／同型篩選、檢舉、看更多、30 秒輪詢） |
| `config.js` | 多了 `SUPABASE_URL` / `SUPABASE_ANON_KEY` |

### ⚠️ 資料庫的設計重點（改之前先讀）

- **前端讀不到 `owner_token` / `session_id` / `status` / `reports`。**
  這是 **column-level GRANT**，不是靠前端自律：直接 curl REST API 也讀不到。
- **管理權限不是「有登入就算」。** 所有管理動作走 `security definer` RPC，
  函式內檢查 `public.moderators` 表。登入但不在名冊裡 → `not a moderator`。
- **踩過的雷：Postgres 建函式時預設把 EXECUTE 給 PUBLIC。**
  所以 migration 第 8 節一定要先 `revoke execute ... from public` 再 grant，
  否則那些 grant 等於沒做事（第一版就是這樣，測出來才發現）。
- **暱稱過濾在 trigger 裡**（`scrub_nickname`）。比對前先轉小寫、去掉所有非文數字，
  所以 `a.d.m.i.n` 這種規避寫法也擋得到。`[:alnum:]` 在 UTF-8 下**會保留中日文**，
  已實測（`阿美 A.B` → `阿美AB`），所以中文封鎖字有效。
- **命中過濾 → `nickname` 設成 null + `nickname_scrubbed = true`**，那筆打卡照樣上牆。
  刻意不給使用者錯誤訊息，免得變成規避教學。`nickname_scrubbed` 只有管理者看得到，
  用來分辨「本來就沒填」和「被過濾掉」。
- **檢舉 3 次自動下架**，可被濫用來惡意藏文，但對 NGO 來說「誤藏」的代價遠低於
  「歧視字眼掛在牆上三小時」，所以刻意選這邊。管理者可以放回去。
- **完全不碰 IP**（連 rate limiting 都不用）。網站對使用者承諾不記錄 IP，
  這個承諾比防灌水更值錢。代價是擋不住腳本灌水 → 真的發生再加
  Cloudflare Turnstile + Edge Function，別回頭去存 IP。

### ✅ 已驗證（本機 Postgres 16 + 假 PostgREST，RLS 是真的在跑）

- 暱稱過濾 11 種情境：中／英／日正常名字保留；網址、`a.d.m.i.n`、`VZT官方`、
  連續字元、中英文封鎖字、電話號碼全部被清掉
- anon 讀 `owner_token`／`session_id`／`status` → permission denied
- anon 自行指定 `status`、UPDATE、DELETE、讀 `blocked_terms` → 全部 denied
- anon 呼叫管理者 RPC → permission denied for function
- 登入但不在 `moderators` 名冊 → `is_moderator()` = false、RPC 丟 not a moderator
- 檢舉 2 次不下架、第 3 次自動下架；管理者可放回
- `delete_soul` 錯 token 回 false、對 token 回 true，且資料**真的被 DELETE**
- 結果頁：勾選框預設不勾、送出鈕預設 disabled；未成年版不顯示暱稱欄位，
  且資料庫該列 `nickname = null` / `nickname_scrubbed = false`（代表從沒送出過）
- 撤回流程：牆上消失 + localStorage 清掉 + 資料庫該列不存在
- 審核台：登入、列表、下架、放回、清名字、封鎖字新增刪除

### 🚧 還沒完成的一件事

**Supabase 專案還沒開。** free 方案每個 owner 最多 2 個 active 專案，
`strata` 與 `schoolzone` 已經佔滿，所以 `create_project` 被擋。
要接上得先選一條路：暫停其中一個、把表建在現有專案裡、或升級 Pro。
在那之前 `config.js` 的兩個 Supabase 欄位留空，世界牆功能整塊隱藏，
網站其他部分完全正常。

接上之後只要三步：跑 migration → 貼 URL/anon key → 建管理員帳號（見 README）。

---

## 📋 3. 待辦 / 下一步

- [ ] **commit + push**（見上方第 1 節；務必含 `git add pedestrian.png`）→ 使用者尚未確認是否上線。
- [ ] 使用者提到「之後用 visionzerotaiwan 來更新」= 日後把改動同步到 `upstream`（Visionzerotaiwan/StreetSoulQuiz），目前**先不做**。
- [ ] 視覺最終確認：早前 session 因 API 圖片數限制，Card 2 的截圖沒能親眼看；功能驗證（內容高 = 容器高 = 1350，無裁切）已過。建議在新對話用 Playwright 重截一張 Card 2 做最終目視確認。
- [ ] **填 `config.js` 的 `SHEET_CSV_URL`**（試算表 → 檔案 → 共用 → 發布到網路 → CSV）。
      沒填的話 `world.html` 只會顯示設定說明、結果頁的世界地圖區塊整塊隱藏 — 不會壞，但也看不到東西。
- [ ] 觀察 Phase 0 的成效（世界地圖有沒有人點、有沒有人分享）。
- [ ] **決定世界牆要用哪個 Supabase 專案**（見 2.7 最後一段），然後跑 migration、貼設定、建管理員。
- [ ] 上線前把 `moderate.html` 的網址只給需要的人（頁面已 `noindex`，但不是密碼保護：
      真正的防線是資料庫的 moderators 名冊，不是網址保密）。

---

## 🧪 4. 如何預覽與測試

**本地預覽**（靜態 server，注意 8000 常被佔用，改用 8123）：

```bash
cd /Users/yunching0513/StreetSoulQuiz
python3 -m http.server 8123
# 開 http://127.0.0.1:8123
```

**Playwright 驗證結果頁的標準做法**（直接跳到指定型，不用真的答 12 題）：

```js
// 1) 強制某個型 + 把 logToSheet 變 no-op（避免污染正式 Google Sheet！）
await page.evaluate(() => {
  window.calculateType = () => 'MECY';   // 任一 4 字代碼
  window.logToSheet   = () => {};        // ← 測試務必 stub，別寫進正式試算表
});
// 2) 呼叫 showResult()（內含 1300ms setTimeout 才 render）
await page.evaluate(() => showResult());
await page.waitForTimeout(1500);
// 3) 要驗 Card 2：呼叫 downloadShareCard() 後檢查產生的兩張卡
```

> **鐵則：測試一定要 stub `logToSheet`**，否則每次測試都會寫一筆假資料到正式 Google Sheet。

---

## 🗺️ 5. 程式架構速查（都在 `index.html`）

- **`TYPES`**（約 line 1079+）：16 型資料物件。每型有 `emoji`、`zh_name`/`en_name`、`rarity`、`desc_*`、`strengths_zh`/`strengths_en`（3 項陣列）、`growth_*`、`action_*`、城市配對 `match_*`、`article_*`、`quote_*`。
- **`renderBondsSection(code)`**：配對區塊。輔助：`AXIS_OPP`（軸對立表）、`flipAxes(code,idxs)`、`buddyReason()`、`luckyReason()`。buddy=`flipAxes(code,[2])`、lucky=`flipAxes(code,[0,1,2,3])`。
- **`buildBondsCard(code,t,isEn)`**（約 line 2667）：分享 Card 2 的 HTML。結構：sc-top → sc2-body（kicker→title→兩格配對→**sc2-strengths 天賦**→sc2-action 雙齊零行動）→ sc-bottom CTA。
- **`canvasFromShareCard(card,fileName)`**：html2canvas 封裝，回傳 `{dataUrl,blob,file,fileName}`。
- **`downloadShareCard()`**：產 Card 1（inline 原 HTML）+ Card 2（buildBondsCard），呼叫 `showImageModal`。
- **`showImageModal({cards,isEn,code})`**：雙卡 modal，每張各自有下載/分享鈕（用 `data-i` 區分）。
- **`renderReadingTabs()` / `switchReadingTab(btn,idx)`**：延伸閱讀 3 分頁（核心讀本／另一種可能／政策論述）。
- **`SFX`** 模組（startQuiz 之前）：IIFE 回傳 `{isMuted,setMuted,tap(i),pop(),pick(),blip(),back(),reveal()}`；另有 `toggleSound()`。
- **intro hero**（約 line 856）：`.intro-hero` > `.intro-hero-text` + `<img class="intro-art" src="pedestrian.png" onerror="this.remove()">`。
- **`.atlas-card`**：在 `renderDemandSection(code)` 之後，地圖成果連結。

**設計 token（`:root`）**：`--lime:#C8D400`、`--lime-dk:#A8B200`、`--coral:#FF6B5B`、`--cream:#FBF7EC`、`--paper:#FFFCF2`、`--black:#1A1A1A`、`--ink:#252525`；字型 `--zh`(Noto Sans TC)、`--en`(Space Grotesk)、`--serif`(DM Serif Display)、`--mono`(JetBrains Mono)。

**16 型代碼**：4 字母 `[pace M/R][route E/H][social C/S][focus Y/I]`。

---

## ⚠️ 6. 重要注意事項（踩過的雷）

- **雙語切換**：靠 `body.zh .en-only{display:none}` / `body.en .zh-only{display:none}`（CSS 約 line 320-321）。`<body>` 必須有 class `zh` 或 `en`。新增雙語內容時用 `.zh-only` / `.en-only` 包。
- **正名**：是「雙**齊**零」不是「雙零」。新增文案別寫回「雙零」。
- **測試別污染試算表**：見第 4 節，務必 stub `logToSheet`。
- **圖片快取雷**：開發時若曾用同檔名 `pedestrian.png` 放過佔位圖，瀏覽器會吃舊快取 → 用 `pedestrian.png?cb=xxx` cache-buster 驗證即可（正式使用者沒有這問題）。
- **`pedestrian.png` 未追蹤**：commit 前一定 `git add`，否則上線會 404（有 `onerror="this.remove()"` 保護，圖會消失但不會壞版）。
- **結果頁是動態 render**：`showResult()` 裡 `setTimeout`（1300ms）才把 HTML 塞進 `#result`。測試要等。
- **`#worldPeek` 是非同步填的**：`loadWorldPeek(code)` 在 `showScreen('result')` 之後才 fetch CSV。
  拿不到資料、CSV 沒設定、或還沒有同型的人 → **整塊 removeChild**，不會留空殼卡片。測試要多等約 1 秒。
- **設定只改 `config.js`**：別再回頭改 `dashboard.html` 裡的 `SHEET_CSV_URL`（那只是舊版 fallback）。
- **世界牆的權限別只看前端**：`supa.js` 寫死要讀哪些欄位只是讓意圖明確，
  真正的防線在 migration 的 column grant 與 RLS。改欄位要同時改 SQL。
- **改 migration 後要重測權限**：本機驗證方式是起一個 Postgres，建 `anon`/`authenticated` 角色
  與 `auth.users` stub，然後 `set role` 跑一遍（這次就是這樣抓到 EXECUTE 給 PUBLIC 的問題）。
- **`world.html` 的底圖 path 不要手改**：它是機器產生的。要重新產生就用 Natural Earth 110m 重跑轉換
  （npm 的 `world-atlas` 套件有資料；jsdelivr 在某些沙箱環境會被擋，用 `npm pack world-atlas@2` 取得）。
