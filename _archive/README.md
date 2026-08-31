# Archived project pages

These pages are kept in the repository but are not published. GitHub Pages
runs Jekyll, and Jekyll does not copy a directory whose name starts with an
underscore into the built site.

## To put a project back on the site

1. Move the page back to the repository root:

   ```
   git mv _archive/rideshare.html .
   ```

2. Open `index.html`. Add the card for that project back into a `#projects`
   section, and add the `Projects` link back to the navigation bar. Commit
   `9c112fc` holds the last version of that section.

3. Commit and push.

The images that these pages use are still in `/images/` and
`/assets/images/projects/`. Do not delete them. The pages break without them.

## What is here, and why

| Page | Archived | Reason |
| --- | --- | --- |
| `credit-card-approval.html` | 2026-08-27 | Rafael took it off the site |
| `uber-data-pipeline.html` | 2026-08-31 | Replaced by the MLOps pipeline project |
| `rideshare.html`, `chicago.html`, `delivery_analysis.html`, `data_jobs.html`, `portbill.html` | 2026 | Replaced by the rebuilt projects |
