# Handoff prompt

Give the text below to the next agent. It is written to be pasted as-is.

---

You continue work on Rafael Tavares' portfolio website. Read this whole
brief before you touch a file.

## 1. Where things are

| Item | Value |
| --- | --- |
| Working copy | `C:\Users\tavar\OneDrive\Ambiente de Trabalho\RafaelTavares98.github.io` |
| Remote | https://github.com/RafaelTavares98/RafaelTavares98.github.io |
| Live site | https://rafaeltavares98.github.io |
| Branch | `main`. A push to `main` deploys the site. |
| Head commit | `358d4a7` |

The `gh` command is installed and the account `RafaelTavares98` is logged
in. Run `gh auth status` to confirm.

There is a second working copy of the same repository in the scratchpad
directory. Ignore it. Use the path in the table.

## 2. Read these files first

Read them in this order. Do not skip step 1.

1. `C:\Users\tavar\OneDrive\Ambiente de Trabalho\over_employment\CLAUDE.md`
   The project rules. They control reply length, writing style, and job
   selection. They override your defaults.
2. `C:\Users\tavar\OneDrive\Ambiente de Trabalho\over_employment\01-profile\facts.md`
   The fixed facts about Rafael. Never write a claim that is not here.
3. `index.html` in the repository. This is the whole live site.
4. `assets/css/style.css`. One stylesheet drives every page.
5. `assets/js/script.js`. Theme switch, scroll header, back-to-top.
6. `_archive/README.md`. How to put a project page back on the site.

Run this to see the history and the reasoning behind each change:

```bash
git -C "C:/Users/tavar/OneDrive/Ambiente de Trabalho/RafaelTavares98.github.io" log --stat -5
```

## 3. What the site is now

The site is one page, `index.html`. The sections are hero, "What I Do",
About, Skills, Tools, and Contact. The navigation bar lists Home, About,
Skills, and Contact.

The front-end is HTML, CSS, Bootstrap 5.3.2, and plain JavaScript. It was
adapted from Vijay Singh's open-source template at
https://github.com/itsvijaysingh/My-Portfolio. Rafael asked for the credit,
and it is in the footer of `index.html`. **Keep that credit.** Vijay's
repository has no licence file, only a request in the README to credit him.

There is no jQuery and no carousel. Do not add them back.

## 4. What was taken off the site, and why it matters

Rafael asked to take every project off the site but keep the files. The
five project pages moved to `_archive/`:

* `_archive/rideshare.html`
* `_archive/chicago.html`
* `_archive/delivery_analysis.html`
* `_archive/data_jobs.html`
* `_archive/portbill.html`

GitHub Pages runs Jekyll. Jekyll does not copy a directory whose name
starts with an underscore into the built site, so these pages return 404.
This is verified. The images the pages use stayed in `/images/` and
`/assets/images/projects/`. **Do not delete those images.** The pages break
without them.

To put a project back, follow `_archive/README.md`. Commit `9c112fc` holds
the last version of the `#projects` section of the homepage.

## 5. Rules you must follow

1. **Never invent a fact about Rafael.** Every claim comes from
   `/01-profile/`. If a fact is missing, ask him.
2. **Keep replies short.** `CLAUDE.md` sets a target of 600 characters and
   a hard limit of 1800. Ask before you send a long reply.
3. **Write in English on the site.** Reply to Rafael in the language he
   writes to you in. He usually writes Portuguese.
4. **Test before you push.** See section 6.
5. **Commit and push only when Rafael asks.** He asked for it every time so
   far, but confirm each time.

## 6. How to test a change

Serve the site and check it. Do not push an untested change.

```bash
cd "C:/Users/tavar/OneDrive/Ambiente de Trabalho/RafaelTavares98.github.io" && python -m http.server 8080
```

Open http://localhost:8080 and confirm:

* The browser console shows no errors.
* No image is broken.
* The light and dark theme button works both ways.
* No link points at a section that does not exist.

Check that every local file a page asks for exists:

```bash
cd "C:/Users/tavar/OneDrive/Ambiente de Trabalho/RafaelTavares98.github.io" && python -c "import re,os,glob,urllib.parse; [print('MISSING',p,s) for p in glob.glob('*.html')+glob.glob('_archive/*.html') for s in re.findall(r'(?:src|href)=\"([^\"]+)\"',open(p,encoding='utf-8').read()) if not s.startswith(('http','#','mailto')) and not os.path.exists(urllib.parse.unquote(s.lstrip('/')))] or print('all assets resolve')"
```

Stop the server when you finish. Find the process and end it:

```bash
netstat -ano | grep ":8080" | grep LISTENING
```

Then run `taskkill //PID <the pid> //F`.

After a push, wait for the deploy and check the live site:

```bash
cd "C:/Users/tavar/OneDrive/Ambiente de Trabalho/RafaelTavares98.github.io" && gh run list --limit 3
```

## 7. Performance. Read this before you add an image

The site was unusable at first. The homepage sent about 11 MB. It now sends
about 1 MB. Do not undo that work.

The causes were, in order of damage:

1. **Oversized images.** One card icon was 2.7 MB. Two card banners were
   over 3 MB each. All were up to 2760 px wide in a slot 370 px wide.
2. **A filter on the fixed background.** `filter: brightness()` on a fixed
   layer forces every `backdrop-filter` on the page to recompute it on each
   frame. It is now a gradient overlay instead.
3. **Too many `backdrop-filter` layers.** The 16 skill and tool cards each
   made a composited layer. They now use a translucent background.
4. **An unthrottled scroll handler.** It now runs inside
   `requestAnimationFrame` with a passive listener.

Rules for any new image:

* Resize it to twice its display width, and no more.
* Save it as WebP at quality 80 to 82.
* Add `loading="lazy"` and `decoding="async"`, unless it is above the fold.

Measure the page weight in the browser console after a change:

```javascript
(() => { const r = performance.getEntriesByType('resource'); let t = 0; r.forEach(e => t += e.transferSize || 0); return {totalKB: Math.round(t/1024), requests: r.length}; })()
```

Keep the homepage under 1.5 MB.

## 8. Open items

1. **`github/Portbill/.env` is public.** It sits in the repository at
   `github/Portbill/.env` and holds `POSTGRES_PASSWORD=portbill`. The
   password is weak and it is a sample, but the file should not be
   published. There is no `.gitignore` in the repository. Rafael was told
   twice and said to leave it for now. Raise it again. Do not act alone.
2. **The `github/` directory is still published.** It holds the Portbill
   source, the Chicago notebook, and the rideshare SQL. Nothing on the site
   links to it, but it is reachable and visible on GitHub. Rafael asked to
   take the projects off the site. Ask him whether this counts.
3. **`test.py` sits in the repository root.** Find out what it is. It looks
   like a leftover.
4. **SQL Server is not installed on this machine.** No `MSSQL*` service, no
   registry key, and no `sqlcmd`, `sqllocaldb`, or `bcp` on the PATH.
   Rafael asked about it. He did not say what he wants to do next.
5. **The projects need a decision.** Rafael took them off the site but did
   not say why or for how long. Ask him what he plans, before you rebuild
   anything.

## 9. What Rafael is doing

He is a data analyst and infrastructure technician in Goiânia, Brazil. He
is looking for a second remote job that pays in US dollars. The portfolio
site supports that search. `CLAUDE.md` holds the rules for which jobs
qualify. Read them before you discuss a job with him.
