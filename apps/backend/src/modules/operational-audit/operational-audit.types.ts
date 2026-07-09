export type OperationalAuditQuery = {
  status?: string;
  direction?: string;
  type?: string;
  limit?: string;
};

export type OperationalAuditExportQuery = OperationalAuditQuery & {
  resource?: string;
  format?: string;
};

export type OperationalAuditHygieneQuery = {
  days?: string;
};

export type OperationalAuditHygienePayload = {
  days?: number;
  dryRun?: boolean;
};

export type OperationalAuditSummaryResponse = {
  success: true;
  data: {
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
  meta: Record<string, never>;
};

export type OperationalAuditMessageItem = {
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

export type OperationalAuditWebhookItem = {
  id: string;
  provider: string;
  eventType: string;
  eventId: string | null;
  status: string;
  createdAt: string;
};

export type OperationalAuditMessagesResponse = {
  success: true;
  data: {
    messages: OperationalAuditMessageItem[];
  };
  meta: Record<string, never>;
};

export type OperationalAuditWebhooksResponse = {
  success: true;
  data: {
    webhooks: OperationalAuditWebhookItem[];
  };
  meta: Record<string, never>;
};

export type OperationalAuditExportResult = {
  filename: string;
  contentType: string;
  content: string;
};

export type OperationalAuditHygieneResponse = {
  success: true;
  data: {
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
  meta: Record<string, never>;
};
