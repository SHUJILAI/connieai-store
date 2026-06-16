/**
 * aiconnie 数据接口 Worker
 * 作用：把题库 / 视频清单放到 Cloudflare KV，只允许 aiconnie.app 来源读取，
 *      避免数据明文躺在公开 GitHub 仓库里、也挡掉别站直接盗刷。
 *
 * 路由（部署后访问）：
 *   GET /km1            -> 科目一题库
 *   GET /km4            -> 科目四题库
 *   GET /videos         -> 抖音视频清单
 *
 * 需要绑定的 KV namespace（变量名 BANK）里预存三个 key：
 *   km1   = km1.json 的内容
 *   km4   = km4.json 的内容
 *   videos= douyin_works.json 的内容
 */

const ALLOW = new Set([
  'https://aiconnie.app',
  'https://www.aiconnie.app',
]);

// 本地开发 / 预览时也放行（按需删）
const ALLOW_PREVIEW = /\.happycapy\.ai$/;

function corsHeaders(origin) {
  const ok = origin && (ALLOW.has(origin) || ALLOW_PREVIEW.test(new URL(origin).hostname));
  return {
    'Access-Control-Allow-Origin': ok ? origin : 'https://aiconnie.app',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Vary': 'Origin',
  };
}

function originAllowed(request) {
  const origin = request.headers.get('Origin');
  const referer = request.headers.get('Referer') || '';
  // 浏览器同源 fetch 会带 Origin；直接 curl 没有 Origin/Referer → 拒绝
  if (origin && (ALLOW.has(origin) || ALLOW_PREVIEW.test(new URL(origin).hostname))) return true;
  if (referer && ([...ALLOW].some(a => referer.startsWith(a)) || ALLOW_PREVIEW.test(new URL(referer).hostname))) return true;
  return false;
}

const KEYS = { '/km1': 'km1', '/km4': 'km4', '/videos': 'videos' };

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin') || '';
    const cors = corsHeaders(origin);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: cors });
    }
    const key = KEYS[url.pathname];
    if (!key) return new Response('Not found', { status: 404, headers: cors });

    if (!originAllowed(request)) {
      return new Response('Forbidden', { status: 403, headers: cors });
    }

    const data = await env.BANK.get(key); // KV 里存的是 JSON 字符串
    if (!data) return new Response('No data', { status: 404, headers: cors });

    return new Response(data, {
      headers: {
        ...cors,
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'public, max-age=3600',
      },
    });
  },
};
