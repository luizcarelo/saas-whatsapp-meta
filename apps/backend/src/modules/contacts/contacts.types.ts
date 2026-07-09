export type ContactPayload = {
  name?: string;
  phone?: string;
  waId?: string;
  email?: string;
  document?: string;
};

export type ContactItem = {
  id: string;
  tenantId: string;
  name: string | null;
  phone: string;
  waId: string | null;
  email: string | null;
  document: string | null;
  createdAt: string;
  updatedAt: string;
};

export type ContactListResponse = {
  success: true;
  data: {
    contacts: ContactItem[];
    total: number;
  };
  meta: Record<string, never>;
};

export type ContactResponse = {
  success: true;
  data: {
    contact: ContactItem;
  };
  meta: Record<string, never>;
};

export type ContactDeleteResponse = {
  success: true;
  data: {
    deleted: true;
    id: string;
  };
  meta: Record<string, never>;
};
