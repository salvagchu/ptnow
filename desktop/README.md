# PTN Team Tracker — Windows desktop app

Electron wrapper around the web app in the repo root (`../index.html`).
The build copies that file into `app/` automatically, so the desktop app
always ships the current version of the site.

## Build a new installer

1. Bump `"version"` in `package.json` (e.g. `1.0.2` → `1.0.3`).
2. From this folder:
   ```
   npm install        # first time only
   npm run dist
   ```
3. The installer is written to `dist/PTN Team Tracker Setup <version>.exe`.
   Running it upgrades an existing install in place; data lives in Supabase.
4. Publish it as a GitHub release:
   ```
   gh release create v<version> "dist/PTN Team Tracker Setup <version>.exe" --title "PTN Team Tracker <version>" --latest
   ```

`npm start` runs the app locally without building an installer.
