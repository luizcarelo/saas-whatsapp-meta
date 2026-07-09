import type { ApiResponse } from '../types/api.types';

const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000/api/v1';

type RequestOptions = {
  token?: string;
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
