import { create } from 'zustand';

type AuthUser = {
  id: string;
  name: string;
  email: string;
};

type AuthState = {
  user: AuthUser | null;
  accessToken: string | null;
  setSession: (user: AuthUser, accessToken: string) => void;
  clearSession: () => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  accessToken: null,
  setSession: (user, accessToken) => set({
    user,
    accessToken
  }),
  clearSession: () => set({
    user: null,
    accessToken: null
  })
}));
