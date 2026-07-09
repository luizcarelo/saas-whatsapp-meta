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
