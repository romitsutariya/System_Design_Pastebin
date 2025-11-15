# Pastebin UI (React + Vite + MUI)

This is a frontend-only Pastebin-style UI built with React, Vite, and Material UI. It provides a create form and a view screen, and can optionally call a backend API.

## Features

- **Create Paste screen**: Large text area + fields `title`, `expiresAt`, `visibility`, `tags`.
- **View Paste screen**: Displays paste content and details. Converts epoch `expiresAt` to a readable date/time.
- **Routing**:
  - `/` create screen
  - `/p/:id` and `/pastes/:id` view screen by ID
  - `/view` view screen via client-side state fallback
- **API service**: `src/services/api.js` with `createPaste()` and `getPaste()`.

## Quick start

1. Install deps
```bash
npm install
```
2. Configure backend URL (optional)
- Create `.env` in project root and set:
```bash
VITE_API_BASE_URL=http://localhost:8000
```
3. Run dev server
```bash
npm run dev
```
The app will start on the shown localhost port (e.g., `http://localhost:5174`).

## Build
```bash
npm run build
npm run preview
```

## Backend contract

- Create paste
  - Method: `POST ${VITE_API_BASE_URL}/pastes`
  - Body example:
```json
{
  "language": "Python",
  "title": "My Paste",
  "content": "print('hello')",
  "expiresAt": 1759415750, // epoch seconds, or "never"
  "visibility": "public",
  "tags": ["leetcode", "algo"],
  "createdAt": "2025-10-02T14:10:00.000Z"
}
```
  - Response example:
```json
{ "id": "<uuid>", "language": "Python", "title": "My Paste", "content": "...", "expiresAt": 1759415750, "visibility": "public", "tags": ["leetcode"] }
```

- Get paste by id
  - Method: `GET ${VITE_API_BASE_URL}/pastes/:id`
  - Response: same shape as above

## Code map

- `src/components/CreatePaste.jsx` – form UI; on submit calls API, then navigates to `/pastes/:id` when available, otherwise to `/view` with state.
- `src/components/ViewPaste.jsx` – reads `:id` from route and fetches; renders loading and error states; formats `expiresAt` from epoch seconds.
- `src/services/api.js` – small `fetch` wrapper using `VITE_API_BASE_URL`.
- `src/App.jsx` – routes.
- `src/main.jsx` – MUI ThemeProvider, CssBaseline, Router.

## Notes

- Tags support comma-separated input or arrays from backend.
- `expiresAt` handling on the view page accepts epoch seconds, numeric strings, ISO strings, or `"never"`.
- If the backend is down, submitting will still navigate to the `/view` page using in-memory state so you can demo the UI.

sudo apt update
sudo apt install python3-pip -y
sudo apt install python3.12-venv