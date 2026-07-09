export type UserProfileRole = {
  id: string;
  name: string;
  description: string | null;
};

export type UserProfilePermission = {
  key: string;
  module: string;
  description: string | null;
};

export type UserProfileTenant = {
  id: string;
  name: string;
  status: string;
};

export type UserProfile = {
  id: string;
  tenantId: string;
  name: string;
  email: string;
  status: string;
  tenant: UserProfileTenant;
  roles: UserProfileRole[];
  permissions: UserProfilePermission[];
};

export type UserProfileResponse = {
  success: true;
  data: {
    user: UserProfile;
  };
  meta: Record<string, never>;
};

export type UserPermissionsResponse = {
  success: true;
  data: {
    permissions: UserProfilePermission[];
  };
  meta: Record<string, never>;
};
