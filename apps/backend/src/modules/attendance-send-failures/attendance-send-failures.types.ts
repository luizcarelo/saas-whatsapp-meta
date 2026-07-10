export type AttendanceSendFailureItem = {
  id: string;
  conversationId: string;
  contactId: string | null;
  contactPhone: string | null;
  whatsappAccountId: string | null;
  phoneNumberId: string | null;
  messageBody: string;
  sentByUserId: string | null;
  sentByName: string;
  departmentName: string;
  conversationStatus: string;
  messageOrigin: string;
  quickReplyId: string | null;
  quickReplyTitle: string | null;
  provider: string;
  providerMessageId: string | null;
  status: string;
  errorMessage: string | null;
  dryRun: boolean;
  attendantSource: string | null;
  assignedUserIdAtSend: string | null;
  assignedUserNameAtSend: string | null;
  retryOfSendId: string | null;
  retryCount: number;
  lastRetryAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceSendFailuresResponse = {
  success: true;
  data: {
    failures: AttendanceSendFailureItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceSendRetryPayload = {
  dryRun?: boolean;
  sentByName?: string | null;
};

export type AttendanceSendRetryResponse = {
  success: true;
  data: {
    original: AttendanceSendFailureItem;
    retry: AttendanceSendFailureItem;
  };
  meta: Record<string, never>;
};

export type AttendanceSendRetriesResponse = {
  success: true;
  data: {
    retries: AttendanceSendFailureItem[];
  };
  meta: Record<string, never>;
};
