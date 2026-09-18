/* ============================================================
   街道靈魂測驗 · 共用設定
   Street Soul Quiz · shared configuration
   ------------------------------------------------------------
   只有這個檔案需要填。dashboard.html、world.html、index.html
   都從這裡讀，不必再一個一個檔案改。
   Fill this file only — the pages read their settings from here.
   ============================================================ */
window.SSQ_CONFIG = {

  /* Google Sheet 發佈成 CSV 的網址。
     取得方式：打開試算表 → 檔案 → 共用 → 發布到網路
              → 選該工作表 → 逗號分隔值 (.csv) → 發布 → 複製網址
     How to get it: Sheet → File → Share → Publish to web → CSV → copy URL */
  SHEET_CSV_URL: '',

  /* 一個國家/地區至少要有幾筆資料，才拿來做跨國比較與下結論。
     低於這個數字仍然會計入總數，但不會出現在「看見差異」的對照裡。
     Minimum sample size before a country is used for cross-country claims. */
  MIN_SAMPLE: 20,

  /* 自動產生的跨國結論，另外要求的最低樣本數（還要通過兩比例 z 檢定）。
     Higher bar for the auto-generated cross-country claim; also z-tested. */
  INSIGHT_MIN: 30

};
