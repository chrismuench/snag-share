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

## 2. Configure the client

### macOS

Run the one-time setup script. It prompts for the Worker URL and upload token, then writes them to `~/.config/snag-share/config` with `chmod 600` permissions:

```bash
./macos/setup.sh
```

Paste the token from your password manager at the hidden prompt. **Paste it exactly once** — the prompt hides the input, so Cmd-V twice silently doubles it and you'll get 401s later.

Verify end-to-end from the terminal:

```bash
screencapture -x /tmp/test.png
./macos/snagit-upload.command /tmp/test.png
# → notification appears, URL is on your clipboard
pbpaste    # to see the URL
```

### Windows

Run the one-time setup script in PowerShell. Same shape as macOS — it prompts for the Worker URL and upload token, writes them to `%USERPROFILE%\.config\snag-share\config`, and tightens the ACL to your user account:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

Paste the token from your password manager at the hidden prompt. **Paste it exactly once** — the prompt hides input, so Ctrl-V twice silently doubles the token.

Test with any PNG:

```cmd
windows\snagit-upload.bat C:\path\to\test.png
```

You should see a toast notification and have the URL on your clipboard.

If you rotate the token later, re-run the setup script — it remembers the endpoint and just prompts for a new token.

## 3. Point Snagit at the uploader

### macOS

Snagit's "Program" share destination on macOS only accepts `.app` bundles — not shell scripts. Build a minimal Automator app that wraps the shell uploader:

```bash
./macos/build-app.sh
```

This produces `macos/Snag Share.app` by copying Apple's signed Automator Application Stub and dropping a workflow XML inside that runs `macos/snagit-upload.command` with the captured file. Because the launcher binary is signed by Apple, Gatekeeper doesn't prompt.

Smoke test the app before wiring it into Snagit:

```bash
open -a "$(pwd)/macos/Snag Share.app" /tmp/test.png
# → same notification + URL on clipboard as the .command test above
```

Then in Snagit:

1. **Snagit menu → Preferences → Share** → click **+** → choose **Program**.
2. In the app picker, select `macos/Snag Share.app`.
3. Name the share "Claude URL" (or whatever you like). Leave arguments at the default — Snagit passes the captured file automatically.
4. Save.

After a capture, click **Share → Claude URL**. The URL lands on your clipboard, no prompts.

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
  worker.js            - the Cloudflare Worker (upload + serve)
  wrangler.toml        - Worker/R2 config
macos/
  setup.sh             - one-time config: writes ~/.config/snag-share/config
  snagit-upload.command - bash uploader called by the .app
  build-app.sh         - builds macos/Snag Share.app (Automator bundle)
windows/
  setup.ps1            - one-time config: writes %USERPROFILE%\.config\snag-share\config
  snagit-upload.ps1    - actual uploader
  snagit-upload.bat    - wrapper Snagit invokes
```

Built artifacts (`macos/Snag Share.app/`) are gitignored — regenerate with `./macos/build-app.sh`.

## Security notes

- The **upload** endpoint requires the bearer token. Anyone without it gets 401 — so randoms can't fill your bucket.
- The **read** endpoint is public by design (unlisted URLs). Don't snag anything you wouldn't paste into a public Gist.
- The 7-day lifecycle rule is the main retention guarantee. URLs stop working after that — so if you need to preserve a screenshot, save a local copy.
- Slugs are 10 chars of `[A-Za-z0-9]` (~8×10¹⁷ combinations), which is not guessable by brute force for any realistic rate limit.

## Troubleshooting

- **`401 unauthorized`** — the client token doesn't match the Worker secret. Most common cause: paste-twice at the hidden token prompt silently doubled the token. Check length:
  - macOS: `source ~/.config/snag-share/config && echo ${#SNAG_SHARE_TOKEN}`
  - Windows (PowerShell): `Select-String SNAG_SHARE_TOKEN= $env:USERPROFILE\.config\snag-share\config | %{ $_.Line.Substring(18).Length }`

  Should print **64**. If it prints 128, re-run the setup script and paste once.
- **Notification says "upload failed"** — run `./macos/snagit-upload.command /tmp/test.png` directly from a terminal; the error is printed there.
- **URL returns 404** — either the 7-day lifecycle ate it, or the slug was copied wrong. Upload a fresh one.
- **Snagit's app picker won't let me select the `.app`** — you haven't run `./macos/build-app.sh` yet, or Snagit is looking at a stale path. The `.app` must exist at `macos/Snag Share.app`.
- **macOS asks "Press Run or Quit to run this script"** — you're pointing Snagit at an older AppleScript-based build, or the `.app` wasn't regenerated via the current `build-app.sh`. Rebuild: `rm -rf "macos/Snag Share.app" && ./macos/build-app.sh`.
- **Snagit on Windows opens a console window briefly** — that's the `.bat` wrapper running PowerShell. Harmless.

## License

Released under the [MIT License](LICENSE). Use it, fork it, ship it — no warranty.
