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

export type AttendanceSendManualData = {
  send: AttendanceSendItem;
};

export type AttendanceSendHistoryData = {
  sends: AttendanceSendItem[];
};
