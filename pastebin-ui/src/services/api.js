const DEFAULT_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

// Simple in-memory cache to dedupe GET requests and avoid duplicate backend hits
// caused by React 18 StrictMode double-invoking effects in development.
const GET_CACHE = new Map(); // key -> { time, promise }
const CACHE_TTL_MS = 10_000; // 10s is enough to cover initial page load duplicates

class ApiClient {
  constructor(baseUrl = DEFAULT_BASE_URL) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async request(path, { method = 'GET', body, headers } = {}) {
    const url = `${this.baseUrl}${path}`;

    // Only dedupe/cache idempotent GET requests without body
    const isCacheableGet = (!body && (method || 'GET').toUpperCase() === 'GET');
    const cacheKey = isCacheableGet ? `${method}:${url}` : null;

    // Serve from cache if an in-flight or recent promise exists
    if (isCacheableGet && cacheKey) {
      const entry = GET_CACHE.get(cacheKey);
      if (entry && (Date.now() - entry.time) < CACHE_TTL_MS) {
        return entry.promise;
      }
    }

    const fetchPromise = (async () => {
      // Attach JWT only for non-GET (e.g., POST) requests
      const authHeader = (!isCacheableGet) ? (() => {
        try {
          const token = sessionStorage.getItem('jwt');
          return token ? { Authorization: `Bearer ${token}` } : {};
        } catch { return {}; }
      })() : {};
      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...authHeader,
          ...(headers || {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });

      const text = await res.text();
      const data = text ? JSON.parse(text) : null;

      if (!res.ok) {
        const message = data?.message || res.statusText || 'Request failed';
        throw new Error(message);
      }
      return data;
    })();

    if (isCacheableGet && cacheKey) {
      // Store the in-flight promise; if it rejects, clear it to avoid caching errors
      GET_CACHE.set(cacheKey, { time: Date.now(), promise: fetchPromise });
      fetchPromise.catch(() => {
        // Avoid leaving a rejected promise in cache
        const current = GET_CACHE.get(cacheKey);
        if (current && current.promise === fetchPromise) {
          GET_CACHE.delete(cacheKey);
        }
      });
    }

    return fetchPromise;
  }

  // Creates a new paste. Expected backend endpoint: POST /pastes
  async createPaste(paste) {
    return this.request('/pastes', { method: 'POST', body: paste });
  }

  // Auth: POST /login -> { token }
  async login(credentials) {
    return this.request('/login', { method: 'POST', body: credentials });
  }

  // Auth: POST /register -> { token }
  async register(credentials) {
    return this.request('/register', { method: 'POST', body: credentials });
  }

  // Gets a paste by ID. Expected backend endpoint: GET /pastes/:id
  async getPaste(id) {
    console.log(id);
    return this.request(`/pastes/${encodeURIComponent(id)}`);
  }
}

export const api = new ApiClient();
export default ApiClient;
