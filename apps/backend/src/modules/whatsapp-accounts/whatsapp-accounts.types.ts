export type WhatsappAccountPayload = {
  wabaId?: string;
  phoneNumberId?: string;
  displayPhoneNumber?: string;
  verifiedName?: string;
  accessToken?: string;
  status?: string;
};

export type WhatsappAccountItem = {
  id: string;
  tenantId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type WhatsappAccountListResponse = {
  success: true;
  data: {
    accounts: WhatsappAccountItem[];
    total: number;
  };
  meta: Record<string, never>;
};

export type WhatsappAccountResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
  };
  meta: Record<string, never>;
};

export type WhatsappAccountDeleteResponse = {
  success: true;
  data: {
    deleted: true;
    id: string;
  };
  meta: Record<string, never>;
};

export type WhatsappTemplateListResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
    templates: unknown;
  };
  meta: Record<string, never>;
};

export type WhatsappOperationalResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
    phoneInfo: unknown;
    templates: unknown;
  };
  meta: Record<string, never>;
};
