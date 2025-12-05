# DeepBible UI

DeepBible is a browser workspace for laying out Bible pericopes from multiple sources, annotating them with your own notes, and pulling in lexical help, cross references, and AI hints without leaving the page. This README focuses on the frontend so you can run it, understand what each panel does, and share workspaces with others.

## Quick start

1. **Enter the frontend environment**
   ```bash
   cd frontend
   nix develop   # or nix-shell if you prefer
   ```
2. **Bundle the PureScript app**
   ```bash
   purs-nix bundle   # or make frontend-build from the repo root
   ```
3. **Serve the static files** (any HTTP server works; one option is built into the Makefile):
   ```bash
   make run
   # ...or inside frontend: python3 -m http.server 8000
   ```
4. Open `http://localhost:8000` and you'll see `deepbible.online` loading pre-populated with John 3:16-17 in four translations so you can explore right away.

While the dev shell is open you can run `watch` (added by `shellHook`) to re-bundle automatically on source changes.

## UI tour

### Search & discovery
- The search bar lives above the workspace. It highlights tokens inline: `@CODE` (yellow) filters by source/translation and `~Book 1,1-10` (red) pins an address range. Anything else is treated as a free text phrase.
- Press **Enter** or click outside the input to run the search. The status line under the bar shows loading progress, API errors, or "No results".
- When the AI helper API reports `status=up`, an **AI toggle** appears. Turn it on to fetch `n8n` powered explanations that complement the regular verse search. AI results reuse the source of your last pericope so explanations stay in the same tradition.
- Click any search or AI result to fetch the verses immediately; a new pericope card is appended using the reported source/address (or the current source for AI entries).

### Workspace items
- The workspace is an ordered list of **pericopes** and **notes**. Between every item you'll see a `+` button that inserts a note at that position; use it for outlines, questions, or commentary.
- Each item header contains a drag handle icon, a duplicate button, and a remove button. Dragging uses native HTML5 events so you can reorder both pericopes and notes.
- Layout changes, inserted passages, note text, and search state are all persisted to the URL hash (see "Sharing layouts" below).

### Pericope cards
- **Address & source editing**: Click the address or source label to edit in place. Addresses accept free-form strings (e.g., `Mk 5,1-20`). The source picker fetches all available translations, groups them by language, filters as you type, and lets you swap translations without leaving the card.
- **Verse grid**: Each verse is rendered with HTML supplied by the backend, so existing formatting (red letters, paragraph markers) survives. Clicking a verse toggles selection; the card remembers selected IDs in a set.
- **Selected address chip**: When you highlight a contiguous range, the margin shows the computed address (e.g., `J 3,16-17`). Clicking it spawns a brand-new pericope using only the selection--handy for narrowing a study.
- **Cross references & stories**: Selecting exactly one verse triggers lookups for cross references, commentaries (with inline hyperlinks annotated per source), and story suggestions. Click a cross reference or story link to fetch those verses into the workspace instantly.
- **Dictionary lane**: Single-verse selection also fetches lexical entries. Each lemma appears as a button; click it to reveal parsing info, gloss, and related forms.

### Notes
- Notes are Markdown-backed. Click the rendered body to edit; blur or press `Esc` to exit editing. The placeholder reminds you that empty notes won't render text.
- Because notes behave like any other item, you can duplicate them, drag them between pericopes, or delete them from the handle menu. They're ideal for outlining sermons, jotting translation differences, or storing prayer prompts alongside the text.

### Drag, duplicate, and contextual actions
- Drag operations are made explicit: when you start dragging one card, hovering other cards marks valid drop zones. Dropping on a card reorders everything serverlessly.
- Duplicate actions fetch fresh verse data for pericopes (to avoid stale selections) and copy note content verbatim. Use duplicates to compare edits or branch a study.
- Clicking anywhere outside cards closes open editors and search popovers so accidental drags don't leave inputs in limbo.

## Sharing layouts

- Every change is serialized into an array of "seeds" (either `{ kind: "pericope", address, source }` or `{ kind: "note", content }`), compressed with `pako`, and written into the URL hash as `#state=...`. Copy the URL to share the exact arrangement, including notes.
- Legacy `?pericopes=...` URLs (address/source pairs separated by `|`) are still understood; visiting one upgrades it to the new compressed hash automatically.
- Browser history is managed via `pushState`, so undo/redo works as expected when you insert or delete items.

## Data providers

The UI talks directly to hosted APIs:

- `https://api.bible.placki.cloud` (PostgREST) for verses, cross references, commentaries, rendered stories, dictionaries, and the source catalog.
- `https://n8n.placki.cloud/webhook/deepbible/*` for AI availability checks and explanation generation.

No credentials are needed; calls are anonymous and read-only.

## Tips & shortcuts

- **Enter / Esc**: in the search input, Enter runs a search and Esc hides results. Inside the source picker, Enter applies the currently typed code, Esc closes the picker. Inside notes, Esc exits editing without removing text.
- **Reuse the last source**: when AI search is active but you haven't loaded a pericope yet, add one manually so the system knows which translation to use for AI follow-ups.
- **Selection-dependent panels**: cross references, commentaries, stories, and dictionary entries only appear when exactly one verse is selected. Clear the selection (click the verse again) to hide them quickly.
- **Combine filters and phrases**: the search regex treats `@source` and `~address` tokens separately, so you can search for `@NVUL ~J 3 Deus amor` to stay within a translation and passage while adding free keywords.

With these pieces you can treat DeepBible as a lightweight "study room" in the browser--assemble passages, drag them into teaching order, attach Markdown notes, and share a single link that recreates it all.
