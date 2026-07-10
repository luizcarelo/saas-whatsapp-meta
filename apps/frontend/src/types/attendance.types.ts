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
