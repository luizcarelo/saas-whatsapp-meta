export type MetaWebhookQuery = {
  'hub.mode'?: string;
  'hub.verify_token'?: string;
  'hub.challenge'?: string;
};

export type MetaWebhookValue = {
  messaging_product?: string;
  metadata?: {
    display_phone_number?: string;
    phone_number_id?: string;
  };
  contacts?: Array<{
    wa_id?: string;
    profile?: {
      name?: string;
    };
  }>;
  messages?: Array<{
    from?: string;
    id?: string;
    timestamp?: string;
    type?: string;
    text?: {
      body?: string;
    };
  }>;
  statuses?: Array<{
    id?: string;
    status?: string;
    timestamp?: string;
    recipient_id?: string;
  }>;
};

export type MetaWebhookPayload = {
  object?: string;
  entry?: Array<{
    id?: string;
    changes?: Array<{
      field?: string;
      value?: MetaWebhookValue;
    }>;
  }>;
};

export type MetaWebhookSignatureResult = {
  valid: boolean;
  required: boolean;
  reason: string;
};

export type MetaWebhookPostResponse = {
  success: true;
  data: {
    received: true;
    events: number;
    messages: number;
    statuses: number;
    signature: {
      required: boolean;
      valid: boolean;
    };
  };
  meta: Record<string, never>;
};
