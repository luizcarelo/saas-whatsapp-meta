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

export type ContactListData = {
  contacts: ContactItem[];
  total: number;
};

export type ContactData = {
  contact: ContactItem;
};

export type ContactDeleteData = {
  deleted: true;
  id: string;
};

export type ContactFormData = {
  name: string;
  phone: string;
  email: string;
  document: string;
};
