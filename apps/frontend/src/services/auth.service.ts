import { apiRequest } from './api';
import type { LoginData, MeData } from '../types/auth.types';

export async function loginRequest(email: string, password: string) {
  return apiRequest<LoginData>('/auth/login', {
    method: 'POST',
    body: {
      email,
      password
    }
  });
}

export async function meRequest(token: string) {
  return apiRequest<MeData>('/auth/me', {
    method: 'GET',
    token
  });
}
