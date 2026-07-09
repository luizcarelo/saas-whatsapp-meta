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

export type WhatsappAccountListData = {
  accounts: WhatsappAccountItem[];
  total: number;
};

export type WhatsappAccountData = {
  account: WhatsappAccountItem;
};

export type WhatsappAccountDeleteData = {
  deleted: true;
  id: string;
};

export type WhatsappAccountFormData = {
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string;
  accessToken: string;
  status: string;
};

export type MetaTemplateItem = {
  id: string;
  name: string;
  language: string;
  status: string;
  category: string;
};

export type MetaTemplatesEnvelope = {
  data?: MetaTemplateItem[];
  paging?: unknown;
};

export type MetaPhoneInfo = {
  id?: string;
  display_phone_number?: string;
  verified_name?: string;
  status?: string;
  quality_rating?: string;
  code_verification_status?: string;
  name_status?: string;
  messaging_limit_tier?: string;
  error?: {
    message?: string;
  };
};

export type WhatsappTemplatesData = {
  account: WhatsappAccountItem;
  templates: MetaTemplatesEnvelope;
};

export type WhatsappOperationalData = {
  account: WhatsappAccountItem;
  phoneInfo: MetaPhoneInfo;
  templates: MetaTemplatesEnvelope;
};
