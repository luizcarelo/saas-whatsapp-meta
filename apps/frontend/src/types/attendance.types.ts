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

export type AttendanceDepartmentsData = {
  departments: AttendanceDepartmentItem[];
};

export type AttendanceDepartmentData = {
  department: AttendanceDepartmentItem;
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

export type AttendanceConversationListData = {
  conversations: AttendanceConversationItem[];
};

export type AttendanceStatusOptionsData = {
  statuses: Array<{
    value: string;
    label: string;
  }>;
  priorities: Array<{
    value: string;
    label: string;
  }>;
};

export type AttendanceUpdateStatusData = {
  conversationId: string;
  status: string;
  priority: string;
  departmentName: string;
  assignedUserId: string | null;
  assignedUserName: string | null;
  updatedAt: string;
};

export type AttendanceAssignConversationData = {
  conversationId: string;
  assignedUserId: string | null;
  assignedUserName: string | null;
  departmentName: string;
  updatedAt: string;
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

export type AttendanceAssignmentHistoryData = {
  assignments: AttendanceAssignmentHistoryItem[];
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

export type AttendanceQuickRepliesData = {
  quickReplies: AttendanceQuickReplyItem[];
};

export type AttendanceQuickReplyData = {
  quickReply: AttendanceQuickReplyItem;
};
