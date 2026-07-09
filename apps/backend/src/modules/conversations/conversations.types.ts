export type CreateConversationPayload = {
  contactId?: string;
  name?: string;
  phone?: string;
  initialMessage?: string;
};

export type CreateConversationMessagePayload = {
  body?: string;
};

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

export type ConversationMessageItem = {
  id: string;
  direction: string;
  type: string;
  body: string | null;
  status: string;
  createdAt: string;
};

export type ConversationDetail = ConversationItem & {
  messages: ConversationMessageItem[];
};

export type ConversationListResponse = {
  success: true;
  data: {
    conversations: ConversationItem[];
    total: number;
  };
  meta: Record<string, never>;
};

export type ConversationResponse = {
  success: true;
  data: {
    conversation: ConversationDetail;
  };
  meta: Record<string, never>;
};

export type ConversationMessageResponse = {
  success: true;
  data: {
    message: ConversationMessageItem;
  };
  meta: Record<string, never>;
};
