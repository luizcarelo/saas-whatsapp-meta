import { create } from 'zustand';
import type { AuthenticatedUser } from '../types/auth.types';

const storageTokenKey = 'saas_whatsapp_access_token';

type AuthState = {
  user: AuthenticatedUser | null;
  accessToken: string | null;
  setSession: (user: AuthenticatedUser, accessToken: string) => void;
  clearSession: () => void;
  loadToken: () => string | null;
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  accessToken: typeof window === 'undefined' ? null : window.localStorage.getItem(storageTokenKey),
  setSession: (user, accessToken) => {
    window.localStorage.setItem(storageTokenKey, accessToken);

    set({
      user,
      accessToken
    });
  },
  clearSession: () => {
    window.localStorage.removeItem(storageTokenKey);

    set({
      user: null,
      accessToken: null
    });
  },
  loadToken: () => {
    if (typeof window === 'undefined') {
      return null;
    }

    return window.localStorage.getItem(storageTokenKey);
  }
}));
