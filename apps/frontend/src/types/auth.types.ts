export type AuthenticatedUser = {
  id: string;
  tenantId: string;
  name: string;
  email: string;
  roles: string[];
  permissions: string[];
};

export type LoginData = {
  access_token: string;
  token_type: string;
  user: AuthenticatedUser;
};

export type MeData = {
  user: AuthenticatedUser;
};
