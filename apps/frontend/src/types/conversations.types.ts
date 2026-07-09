export type ConversationStatus = 'open' | 'pending' | 'bot' | 'human' | 'resolved';

export type ConversationPreview = {
  id: string;
  contactName: string;
  phone: string;
  status: ConversationStatus;
  lastMessage: string;
  lastMessageAt: string;
  unreadCount: number;
};

export type ConversationMessage = {
  id: string;
  direction: 'inbound' | 'outbound';
  body: string;
  createdAt: string;
};
