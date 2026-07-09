import type { ApiResponse } from '../types/api.types';

function getApiBaseUrl(): string {
  const configuredUrl = import.meta.env.VITE_API_URL as string | undefined;

  if (configuredUrl && configuredUrl.length > 0) {
    return configuredUrl;
  }

  if (typeof window !== 'undefined') {
    return `${window.location.origin}/api/v1`;
  }

  return 'http://127.0.0.1:3300/api/v1';
}

const apiBaseUrl = getApiBaseUrl();

type RequestOptions = {
  token?: string | null;
  method?: string;
  body?: unknown;
};

export async function apiRequest<T>(
  path: string,
  options: RequestOptions = {}
): Promise<ApiResponse<T>> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json'
  };

  if (options.token) {
    headers.Authorization = `Bearer ${options.token}`;
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined
  });

  const data = await response.json();

  return data as ApiResponse<T>;
}
