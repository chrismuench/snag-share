# snag-share — a Snagit sharing destination for Claude Code

A tiny pipeline that turns any Snagit screenshot into a public HTTPS URL you can paste into Claude Code. Snagit exports the PNG → a small script on your machine uploads it to a Cloudflare Worker backed by R2 → the URL is copied to your clipboard. Files auto-delete after 7 days.

```
Snagit  ─▶  snagit-upload (mac/windows)  ─▶  POST /upload  ─▶  Cloudflare Worker  ─▶  R2
                                                                       │
   clipboard  ◀──────────  https://…/abc123.png  ◀────────────────────┘
```

## Prerequisites

- A free Cloudflare account (R2 requires adding a card, but the free tier covers this use case comfortably)
- Node.js 18+ and `npx` available in a terminal
- Snagit installed

## 1. Deploy the Worker

```bash
cd worker
npx wrangler login                                   # browser-based auth
npx wrangler r2 bucket create snag-share             # create the bucket
TOKEN=$(openssl rand -hex 32)                        # generate an upload secret
echo "$TOKEN"                                        # keep this — clients need it
echo "$TOKEN" | npx wrangler secret put UPLOAD_TOKEN # attach it to the Worker
npx wrangler deploy
```

Wrangler prints the Worker's public URL, for example:

```
https://snag-share.<your-subdomain>.workers.dev
```

Hit `/` in a browser — it should return `snag-share ok`.

### Auto-delete after 7 days

In the Cloudflare dashboard: **R2 → snag-share → Settings → Object lifecycle rules → Add rule**. Set *Delete objects* after **7 days**, applied to the whole bucket.

(Or via CLI, if wrangler on your machine supports it: `npx wrangler r2 bucket lifecycle add snag-share --expire-days 7`.)

### (Optional) pretty custom domain

If you want URLs like `https://snag.example.com/abc123.png` instead of `*.workers.dev`:

1. In the Worker's Cloudflare dashboard, go to **Settings → Domains & Routes → Add → Custom Domain** and point a subdomain at it.
2. Uncomment the `[vars]` / `PUBLIC_BASE_URL` lines in `worker/wrangler.toml`, set it to that domain, and redeploy with `npx wrangler deploy`.

## 2. Configure the client script

Open the client script for your OS and replace the two placeholders at the top (endpoint URL and upload token). If you'd rather not hardcode the token, set them as environment variables instead:

**macOS** (add to `~/.zshenv`):

```sh
export SNAG_SHARE_ENDPOINT="https://snag-share.<your-subdomain>.workers.dev"
export SNAG_SHARE_TOKEN="<the token you generated above>"
```

**Windows** (PowerShell, one-time):

```powershell
[Environment]::SetEnvironmentVariable('SNAG_SHARE_ENDPOINT', 'https://snag-share.<your-subdomain>.workers.dev', 'User')
[Environment]::SetEnvironmentVariable('SNAG_SHARE_TOKEN', '<the token you generated above>', 'User')
```

Test it from a terminal with any PNG file:

```sh
# macOS
./macos/snagit-upload.command ~/Desktop/test.png
# Windows
windows\snagit-upload.bat  C:\path\to\test.png
```

You should see a notification, and the URL should be on your clipboard.

## 3. Point Snagit at the script

### macOS

1. Snagit menu → **Preferences → Share → ➕ (add share) → Program**.
2. For **Application**, pick `macos/snagit-upload.command`.
3. For **Arguments**, choose/pass the file path (Snagit's UI calls this *Snagit File Path* or similar — leave it at the default "pass the captured file").
4. Save. Name the share "Claude URL" or whatever you prefer.

After a capture, click Share → Claude URL. The URL lands on your clipboard.

### Windows

1. In Snagit Editor, open **File → Share Properties** (or **Outputs** on the capture toolbar) → **Add Output → Program**.
2. For **Program**, point at `windows\snagit-upload.bat`.
3. For **Arguments**, use `"%1"` (Snagit substitutes the captured file path).
4. Set **File format** to PNG if it isn't already.
5. Save.

## 4. Use with Claude Code

After any Snagit capture → share to the new destination → paste the URL into Claude Code. Claude Code can fetch the image directly since it's a plain HTTPS PNG.

## Files

```
worker/
  worker.js          - the Cloudflare Worker (upload + serve)
  wrangler.toml      - Worker/R2 config
macos/
  snagit-upload.command
windows/
  snagit-upload.ps1  - actual uploader
  snagit-upload.bat  - wrapper Snagit invokes
```

## Security notes

- The **upload** endpoint requires the bearer token. Anyone without it gets 401 — so randoms can't fill your bucket.
- The **read** endpoint is public by design (unlisted URLs). Don't snag anything you wouldn't paste into a public Gist.
- The 7-day lifecycle rule is the main retention guarantee. URLs stop working after that — so if you need to preserve a screenshot, save a local copy.
- Slugs are 10 chars of `[A-Za-z0-9]` (~8×10¹⁷ combinations), which is not guessable by brute force for any realistic rate limit.

## Troubleshooting

- **`401 unauthorized`** — token in the client doesn't match the Worker secret. Re-run `wrangler secret put UPLOAD_TOKEN` and update the client.
- **Notification says "upload failed"** — run the client script manually from a terminal on a test PNG; the error message will be more visible.
- **URL returns 404** — either the 7-day lifecycle ate it, or the slug was copied wrong. Upload a fresh one.
- **Snagit on Windows opens a console window briefly** — that's the `.bat` wrapper running PowerShell. Harmless. To hide it, you can wrap further in a VBScript or use `conhost.exe` launch flags, but it's usually not worth the hassle.

## License

Released under the [MIT License](LICENSE). Use it, fork it, ship it — no warranty.
