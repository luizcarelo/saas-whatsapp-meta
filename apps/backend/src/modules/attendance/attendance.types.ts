export type AttendanceConversationStatus =
  | 'novo'
  | 'em_atendimento'
  | 'aguardando_cliente'
  | 'aguardando_interno'
  | 'resolvido'
  | 'encerrado'
  | 'arquivado';

export type AttendancePriority =
  | 'baixa'
  | 'normal'
  | 'media'
  | 'alta'
  | 'urgente';

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
