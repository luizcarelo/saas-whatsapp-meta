export type ConversationContact = {
  id: string;
  name: string | null;
  phone: string;
  email: string | null;
};

export type MessageStatus =
  | 'pending'
  | 'received'
  | 'sent'
  | 'delivered'
  | 'read'
  | 'failed';

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
  status: MessageStatus | string;
  providerMessageId?: string | null;
  sentAt?: string | null;
  metadata?: unknown;
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

export type MessageStatusSummary = {
  pending: number;
  received: number;
  sent: number;
  delivered: number;
  read: number;
  failed: number;
};

export type SendTemplateFormData = {
  templateName: string;
  languageCode: string;
};
