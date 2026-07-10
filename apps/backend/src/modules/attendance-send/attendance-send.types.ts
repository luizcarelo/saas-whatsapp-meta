export type AttendanceSendOrigin =
  | 'manual'
  | 'quick_reply'
  | 'closing_rating'
  | 'automation_greeting'
  | 'automation_transfer'
  | 'automation_waiting_customer'
  | 'automation_out_of_hours'
  | 'automation_unassigned';

export type AttendanceSendStatus =
  | 'pending'
  | 'sent'
  | 'failed'
  | 'dry_run';

export type AttendanceSendManualPayload = {
  messageBody?: string;
  sentByUserId?: string | null;
  sentByName?: string | null;
  departmentName?: string;
  messageOrigin?: AttendanceSendOrigin;
  quickReplyId?: string | null;
  quickReplyTitle?: string | null;
  dryRun?: boolean;
  attendantSource?: string;
  assignedUserIdAtSend?: string | null;
  assignedUserNameAtSend?: string | null;
};

export type AttendanceSendItem = {
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
  attendantSource: string;
  assignedUserIdAtSend: string | null;
  assignedUserNameAtSend: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceSendManualResponse = {
  success: true;
  data: {
    send: AttendanceSendItem;
  };
  meta: Record<string, never>;
};

export type AttendanceSendHistoryResponse = {
  success: true;
  data: {
    sends: AttendanceSendItem[];
  };
  meta: Record<string, never>;
};
