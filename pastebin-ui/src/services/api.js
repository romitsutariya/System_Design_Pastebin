const DEFAULT_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

class ApiClient {
  constructor(baseUrl = DEFAULT_BASE_URL) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async request(path, { method = 'GET', body, headers } = {}) {
    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
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
  }

  // Creates a new paste. Expected backend endpoint: POST /pastes
  async createPaste(paste) {
    return this.request('/pastes', { method: 'POST', body: paste });
  }

  // Gets a paste by ID. Expected backend endpoint: GET /pastes/:id
  async getPaste(id) {
    return this.request(`/pastes/${encodeURIComponent(id)}`);
  }
}

export const api = new ApiClient();
export default ApiClient;
