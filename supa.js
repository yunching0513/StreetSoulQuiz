/* ============================================================
   街道靈魂測驗 · 世界牆的資料層
   Street Soul Quiz · wall data layer
   ------------------------------------------------------------
   直接打 Supabase 的 PostgREST / GoTrue endpoint，不載入 supabase-js。
   理由跟整個專案一樣：不要有 build、不要多一個 CDN 可以壞。
   安全性完全靠資料庫的 RLS 與 column grant，不靠這個檔案。
   ============================================================ */
window.SSQ = (function(){
  const cfg  = window.SSQ_CONFIG || {};
  const BASE = String(cfg.SUPABASE_URL || '').replace(/\/+$/, '');
  const KEY  = String(cfg.SUPABASE_ANON_KEY || '');
  const ready = !!(BASE && KEY);

  /* 前端要讀的欄位。owner_token / session_id / status 沒有授權給 anon，
     這裡寫死是為了讓意圖明確，真正的防線在資料庫。 */
  const WALL_COLS = 'id,created_at,type_code,nickname,country,city,lang';

  function headers(token, extra){
    return Object.assign({
      'apikey': KEY,
      'Authorization': 'Bearer ' + (token || KEY),
      'Content-Type': 'application/json'
    }, extra || {});
  }

  async function request(path, opts){
    if(!ready) throw new Error('wall not configured');
    const res = await fetch(BASE + path, opts);
    if(!res.ok){
      let detail = '';
      try { detail = (await res.json()).message || ''; } catch(e){}
      const err = new Error('HTTP ' + res.status + (detail ? ' · ' + detail : ''));
      err.status = res.status;
      throw err;
    }
    if(res.status === 204) return null;
    const text = await res.text();
    return text ? JSON.parse(text) : null;
  }

  /* 訪客 id：只是一個隨機 UUID，存在訪客自己的瀏覽器裡。
     不是帳號、不跟任何身分連結，清掉瀏覽器資料就會換一個新的。 */
  const VISITOR_KEY = 'ssq-visitor';
  function uuid(){
    const c = window.crypto || window.msCrypto;
    if(c && c.randomUUID) return c.randomUUID();
    const a = new Uint8Array(16);
    c.getRandomValues(a);
    a[6] = (a[6] & 0x0f) | 0x40;   // version 4
    a[8] = (a[8] & 0x3f) | 0x80;   // variant
    const h = Array.from(a, b => b.toString(16).padStart(2,'0')).join('');
    return h.slice(0,8)+'-'+h.slice(8,12)+'-'+h.slice(12,16)+'-'+h.slice(16,20)+'-'+h.slice(20);
  }
  function visitorId(){
    try{
      const saved = localStorage.getItem(VISITOR_KEY);
      if(saved && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(saved)) return saved;
      const fresh = uuid();
      localStorage.setItem(VISITOR_KEY, fresh);
      return fresh;
    }catch(e){
      return uuid();   // 無痕視窗：這次造訪照樣算得到，只是下次會是新的
    }
  }

  function newToken(){
    const a = new Uint8Array(16);
    (window.crypto || window.msCrypto).getRandomValues(a);
    return Array.from(a, b => b.toString(16).padStart(2,'0')).join('');
  }

  return {
    ready,
    newToken,

    /* 打卡。row 只帶使用者同意公開的欄位。 */
    async addSoul(row){
      // 明確指定回傳欄位：owner_token 沒有授權給 anon，
      // 不指定的話 PostgREST 可能會想回傳整列而撞上欄位權限。
      const out = await request('/rest/v1/wall_souls?select=' + WALL_COLS, {
        method: 'POST',
        headers: headers(null, {'Prefer': 'return=representation'}),
        body: JSON.stringify(row)
      });
      return Array.isArray(out) ? out[0] : out;
    },

    /* 讀牆。type 給 4 碼就只看同型的。 */
    async wall({limit = 48, before = null, type = null} = {}){
      let q = '/rest/v1/wall_souls?select=' + WALL_COLS + '&order=created_at.desc&limit=' + limit;
      if(type) q += '&type_code=eq.' + encodeURIComponent(type);
      if(before) q += '&created_at=lt.' + encodeURIComponent(before);
      return await request(q, {headers: headers()}) || [];
    },

    /* 牆上總共幾筆（PostgREST 用 Content-Range 回總數）。 */
    async wallCount(type){
      if(!ready) throw new Error('wall not configured');
      let q = '/rest/v1/wall_souls?select=id&limit=1';
      if(type) q += '&type_code=eq.' + encodeURIComponent(type);
      const res = await fetch(BASE + q, {headers: headers(null, {'Prefer': 'count=exact'})});
      if(!res.ok) throw new Error('HTTP ' + res.status);
      const range = res.headers.get('content-range') || '';
      const total = parseInt(range.split('/')[1], 10);
      return isNaN(total) ? null : total;
    },

    /* 記一次造訪。同一個瀏覽器同一天重複呼叫不會重複計數（資料庫端擋）。 */
    async countVisit(){
      return request('/rest/v1/rpc/wall_log_visit', {
        method: 'POST', headers: headers(), body: JSON.stringify({p_visitor: visitorId()})
      });
    },

    /* 讀造訪統計。回傳 {total, today, since}。 */
    async visitStats(){
      const out = await request('/rest/v1/rpc/wall_visit_stats', {
        method: 'POST', headers: headers(), body: JSON.stringify({})
      });
      return Array.isArray(out) ? (out[0] || null) : out;
    },

    async report(id){
      return request('/rest/v1/rpc/wall_report_soul', {
        method: 'POST', headers: headers(), body: JSON.stringify({p_id: id})
      });
    },

    async removeSoul(id, token){
      return request('/rest/v1/rpc/wall_delete_soul', {
        method: 'POST', headers: headers(), body: JSON.stringify({p_id: id, p_token: token})
      });
    },

    /* ---- 以下只有 moderate.html 用得到 ---- */
    async signIn(email, password){
      const res = await fetch(BASE + '/auth/v1/token?grant_type=password', {
        method: 'POST',
        headers: {'apikey': KEY, 'Content-Type': 'application/json'},
        body: JSON.stringify({email, password})
      });
      const body = await res.json().catch(()=>({}));
      if(!res.ok) throw new Error(body.error_description || body.msg || ('HTTP ' + res.status));
      return body;   // {access_token, refresh_token, user, ...}
    },

    async rpc(name, args, token){
      return request('/rest/v1/rpc/' + name, {
        method: 'POST', headers: headers(token), body: JSON.stringify(args || {})
      });
    }
  };
})();
