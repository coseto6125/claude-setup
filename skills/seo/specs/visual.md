# Visual spec

Capture screenshots, test mobile rendering, and analyze above-the-fold content using Playwright.

## Prerequisites

Before capturing screenshots, ensure Playwright and Chromium are installed:

```bash
pip install playwright && playwright install chromium
```

## Steps

1. Capture a desktop screenshot (1920x1080) and a mobile screenshot (375x812, iPhone viewport) with:
   ```bash
   "$HOME/.claude/skills/seo/bin/claude-seo" run capture_screenshot.py URL --all --output screenshots/
   "$HOME/.claude/skills/seo/bin/claude-seo" run render_page.py URL --mode auto --a11y-tree --json
   ```
2. Analyze above-the-fold content: is the primary CTA visible?
3. Check for visual layout issues and overlapping elements.
4. Verify mobile responsiveness.

## Reference

### Viewports to test

| Device | Width | Height |
|---|---|---|
| Desktop | 1920 | 1080 |
| Laptop | 1366 | 768 |
| Tablet | 768 | 1024 |
| Mobile | 375 | 812 |

### Above-the-fold analysis

- Primary heading (H1) visible without scrolling.
- Main CTA visible without scrolling.
- Hero image/content loading properly.
- No layout shifts on load.

### Mobile responsiveness

- Navigation accessible (hamburger menu or visible).
- Touch targets at least 48x48px.
- No horizontal scroll.
- Text readable without zooming (16px+ base font).

### Visual issues to flag

- Overlapping elements.
- Text cut off or overflow.
- Images not scaling properly.
- Broken layout at different widths.

## Output

Report: visual analysis summary, mobile responsiveness assessment, above-the-fold content evaluation, and specific issues with element locations.

- `output_dir/screenshots/desktop.png` and `output_dir/screenshots/mobile.png` when capture succeeds
- findings file: `findings/visual.md` — above-the-fold, mobile, layout, and accessibility-tree findings
- `audit-data.json` category: Visual
