# DeepBible PureScript frontend

This directory contains a minimal PureScript/Halogen single page component that talks to the PostgREST API exposed by the DeepBible database helpers.

## Prerequisites

* [Spago](https://github.com/purescript/spago)
* Node.js runtime (for running the generated JavaScript bundle)

## Install dependencies and build

```bash
cd frontend
spago install
spago bundle-app --main Main --to app.js
```

The generated bundle will live in `app.js`. You can then serve the contents of the `frontend` directory using any static file server, for example:

```bash
npx http-server .
```

## Using the app

1. Start your PostgREST server that exposes the functions defined in `sql/postgrest.sql` (the default URL in the component points at `http://localhost:3000`).
2. Open `index.html` in your browser (or visit the URL where you serve the `frontend` directory).
3. Use the address textarea to provide verse addresses, separated by semicolons. Example: `Genesis 1,1-5; John 3,16`.
4. Choose translations from the available list. They will appear in the order selected; use the arrow buttons to rearrange or remove them.
5. Click **Fetch verses** to load the passages. Each translation will be displayed in its own column, with verse references in the left margin.

The layout keeps metadata tucked into a narrow margin so that the verse text remains the visual focus.
