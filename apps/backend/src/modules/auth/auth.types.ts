export type AuthenticatedUser = {
  id: string;
  tenantId: string;
  name: string;
  email: string;
  roles: string[];
  permissions: string[];
};

export type LoginResponse = {
  success: true;
  data: {
    access_token: string;
    token_type: string;
    user: AuthenticatedUser;
  };
  meta: Record<string, never>;
};

export type MeResponse = {
  success: true;
  data: {
    user: AuthenticatedUser;
  };
  meta: Record<string, never>;
};
