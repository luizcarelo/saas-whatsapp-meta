export type ConversationContact = {
  id: string;
  name: string | null;
  phone: string;
  email: string | null;
};

export type ConversationLastMessage = {
  id: string;
  direction: string;
  body: string | null;
  createdAt: string;
};

export type ConversationMessage = {
  id: string;
  direction: string;
  type: string;
  body: string | null;
  status: string;
  createdAt: string;
};

export type ConversationItem = {
  id: string;
  tenantId: string;
  contact: ConversationContact;
  status: string;
  channel: string;
  lastMessageAt: string | null;
  createdAt: string;
  updatedAt: string;
  lastMessage: ConversationLastMessage | null;
};

export type ConversationDetail = ConversationItem & {
  messages: ConversationMessage[];
};

export type ConversationListData = {
  conversations: ConversationItem[];
  total: number;
};

export type ConversationData = {
  conversation: ConversationDetail;
};

export type ConversationMessageData = {
  message: ConversationMessage;
};

export type ConversationFormData = {
  name: string;
  phone: string;
  initialMessage: string;
};
