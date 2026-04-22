// Cloudflare Worker: receives a PNG upload, stores it in R2, returns a public URL.
// GET /<slug>.<ext>  -> streams the image back (what Claude Code will fetch)
// POST /upload       -> accepts binary image body, requires Bearer token, returns URL

const ALPHABET =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

function randomSlug(length = 10) {
  const arr = new Uint8Array(length);
  crypto.getRandomValues(arr);
  let s = "";
  for (const b of arr) s += ALPHABET[b % ALPHABET.length];
  return s;
}

function extFromContentType(ct) {
  const map = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/gif": "gif",
    "image/webp": "webp",
  };
  return map[ct.toLowerCase()] || null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // --- Upload endpoint ---
    if (request.method === "POST" && url.pathname === "/upload") {
      const auth = request.headers.get("authorization") || "";
      if (auth !== `Bearer ${env.UPLOAD_TOKEN}`) {
        return new Response("unauthorized\n", { status: 401 });
      }

      const ct = (request.headers.get("content-type") || "").split(";")[0].trim();
      const ext = extFromContentType(ct);
      if (!ext) {
        return new Response(
          "content-type must be image/png, image/jpeg, image/gif, or image/webp\n",
          { status: 400 }
        );
      }

      if (!request.body) {
        return new Response("missing body\n", { status: 400 });
      }

      const slug = randomSlug();
      const key = `${slug}.${ext}`;

      await env.BUCKET.put(key, request.body, {
        httpMetadata: { contentType: ct },
      });

      // Prefer a custom domain if one is configured; otherwise use the request origin.
      const base = env.PUBLIC_BASE_URL
        ? env.PUBLIC_BASE_URL.replace(/\/+$/, "")
        : url.origin;
      const publicUrl = `${base}/${key}`;

      return new Response(publicUrl + "\n", {
        status: 200,
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    // --- Health check ---
    if (request.method === "GET" && url.pathname === "/") {
      return new Response("snag-share ok\n", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    // --- Serve an uploaded image ---
    if (request.method === "GET" || request.method === "HEAD") {
      const key = decodeURIComponent(url.pathname.replace(/^\/+/, ""));
      // only single-segment keys are valid (slug.ext)
      if (!key || key.includes("/") || !/^[A-Za-z0-9]+\.[a-z]+$/.test(key)) {
        return new Response("not found\n", { status: 404 });
      }

      const object = await env.BUCKET.get(key);
      if (!object) return new Response("not found\n", { status: 404 });

      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      headers.set("cache-control", "public, max-age=31536000, immutable");
      headers.set("x-content-type-options", "nosniff");

      return new Response(request.method === "HEAD" ? null : object.body, {
        headers,
      });
    }

    return new Response("method not allowed\n", { status: 405 });
  },
};
