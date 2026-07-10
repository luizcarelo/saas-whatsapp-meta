export type AttendanceDepartmentItem = {
  id: string;
  name: string;
  slug: string;
  color: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceDepartmentsResponse = {
  success: true;
  data: {
    departments: AttendanceDepartmentItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceDepartmentPayload = {
  name?: string;
  color?: string;
  isActive?: boolean;
  sortOrder?: number;
};

export type AttendanceDepartmentResponse = {
  success: true;
  data: {
    department: AttendanceDepartmentItem;
  };
  meta: Record<string, never>;
};

export type AttendanceConversationItem = {
  id: string;
  contactName: string | null;
  contactPhone: string | null;
  status: string;
  priority: string;
  departmentName: string;
  assignedUserId: string | null;
  assignedUserName: string | null;
  lastMessage: string | null;
  lastMessageAt: string | null;
  unreadCount: number;
  updatedAt: string;
};

export type AttendanceConversationListResponse = {
  success: true;
  data: {
    conversations: AttendanceConversationItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceStatusOptionsResponse = {
  success: true;
  data: {
    statuses: Array<{
      value: string;
      label: string;
    }>;
    priorities: Array<{
      value: string;
      label: string;
    }>;
  };
  meta: Record<string, never>;
};

export type AttendanceUpdateStatusPayload = {
  status?: string;
  priority?: string;
  departmentName?: string;
  assignedUserId?: string | null;
  assignedUserName?: string | null;
};

export type AttendanceUpdateStatusResponse = {
  success: true;
  data: {
    conversationId: string;
    status: string;
    priority: string;
    departmentName: string;
    assignedUserId: string | null;
    assignedUserName: string | null;
    updatedAt: string;
  };
  meta: Record<string, never>;
};

export type AttendanceAssignConversationPayload = {
  assignedUserId?: string | null;
  assignedUserName?: string | null;
  departmentName?: string;
  action?: string;
};

export type AttendanceAssignConversationResponse = {
  success: true;
  data: {
    conversationId: string;
    assignedUserId: string | null;
    assignedUserName: string | null;
    departmentName: string;
    updatedAt: string;
  };
  meta: Record<string, never>;
};

export type AttendanceAssignmentHistoryItem = {
  id: string;
  conversationId: string;
  assignedUserId: string | null;
  assignedUserName: string;
  departmentName: string;
  action: string;
  createdAt: string;
};

export type AttendanceAssignmentHistoryResponse = {
  success: true;
  data: {
    assignments: AttendanceAssignmentHistoryItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceQuickReplyItem = {
  id: string;
  departmentName: string;
  title: string;
  message: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceQuickRepliesResponse = {
  success: true;
  data: {
    quickReplies: AttendanceQuickReplyItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceQuickReplyPayload = {
  departmentName?: string;
  title?: string;
  message?: string;
  isActive?: boolean;
  sortOrder?: number;
};

export type AttendanceQuickReplyResponse = {
  success: true;
  data: {
    quickReply: AttendanceQuickReplyItem;
  };
  meta: Record<string, never>;
};
