export type AuditSummary = {
  messages: {
    total: number;
    sent: number;
    delivered: number;
    read: number;
    failed: number;
    pending: number;
    received: number;
  };
  webhooks: {
    total: number;
    received: number;
    processed: number;
    failed: number;
  };
  conversations: {
    visible: number;
    deleted: number;
  };
  accounts: {
    active: number;
    deleted: number;
  };
};

export type AuditMessageItem = {
  id: string;
  conversationId: string;
  contactName: string | null;
  contactPhone: string | null;
  direction: string;
  type: string;
  status: string;
  body: string | null;
  providerMessageId: string | null;
  sentAt: string | null;
  createdAt: string;
  errorMessage: string | null;
};

export type AuditWebhookItem = {
  id: string;
  provider: string;
  eventType: string;
  eventId: string | null;
  status: string;
  createdAt: string;
};

export type AuditHygieneResult = {
  dryRun: boolean;
  days: number;
  cutoff: string;
  candidates: {
    oldMessages: number;
    oldFailedMessagesWithMetadata: number;
    oldWebhookEvents: number;
  };
  changed: {
    messagesRedacted: number;
    webhookEventsRedacted: number;
  };
};

export type AuditSummaryData = AuditSummary;

export type AuditMessagesData = {
  messages: AuditMessageItem[];
};

export type AuditWebhooksData = {
  webhooks: AuditWebhookItem[];
};

export type AuditHygieneData = AuditHygieneResult;
