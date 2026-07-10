import { apiRequest } from './api';
import type {
  AttendanceAssignConversationData,
  AttendanceAssignmentHistoryData,
  AttendanceConversationListData,
  AttendanceDepartmentData,
  AttendanceDepartmentsData,
  AttendanceQuickRepliesData,
  AttendanceQuickReplyData,
  AttendanceStatusOptionsData,
  AttendanceUpdateStatusData
} from '../types/attendance.types';

export async function listAttendanceDepartmentsRequest(token: string) {
  return apiRequest<AttendanceDepartmentsData>('/attendance/departments', {
    method: 'GET',
    token
  });
}

export async function createAttendanceDepartmentRequest(
  token: string,
  payload: {
    name: string;
    color?: string;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceDepartmentData>('/attendance/departments', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function updateAttendanceDepartmentRequest(
  token: string,
  departmentId: string,
  payload: {
    name?: string;
    color?: string;
    isActive?: boolean;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceDepartmentData>('/attendance/departments/' + departmentId, {
    method: 'PATCH',
    token,
    body: payload
  });
}

export async function listAttendanceConversationsRequest(token: string) {
  return apiRequest<AttendanceConversationListData>('/attendance/conversations', {
    method: 'GET',
    token
  });
}

export async function getAttendanceStatusOptionsRequest(token: string) {
  return apiRequest<AttendanceStatusOptionsData>('/attendance/conversations/status-options', {
    method: 'GET',
    token
  });
}

export async function updateAttendanceConversationStatusRequest(
  token: string,
  conversationId: string,
  payload: {
    status: string;
    priority: string;
    departmentName: string;
    assignedUserId?: string | null;
    assignedUserName?: string | null;
  }
) {
  return apiRequest<AttendanceUpdateStatusData>('/attendance/conversations/' + conversationId + '/status', {
    method: 'PATCH',
    token,
    body: payload
  });
}

export async function assignAttendanceConversationRequest(
  token: string,
  conversationId: string,
  payload: {
    assignedUserId?: string | null;
    assignedUserName: string;
    departmentName: string;
    action?: string;
  }
) {
  return apiRequest<AttendanceAssignConversationData>('/attendance/conversations/' + conversationId + '/assignee', {
    method: 'PATCH',
    token,
    body: payload
  });
}

export async function listAttendanceAssignmentHistoryRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceAssignmentHistoryData>('/attendance/conversations/' + conversationId + '/assignments', {
    method: 'GET',
    token
  });
}

export async function listAttendanceQuickRepliesRequest(
  token: string,
  departmentName?: string
) {
  const suffix = departmentName ? '?departmentName=' + encodeURIComponent(departmentName) : '';

  return apiRequest<AttendanceQuickRepliesData>('/attendance/quick-replies' + suffix, {
    method: 'GET',
    token
  });
}

export async function createAttendanceQuickReplyRequest(
  token: string,
  payload: {
    departmentName: string;
    title: string;
    message: string;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceQuickReplyData>('/attendance/quick-replies', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function updateAttendanceQuickReplyRequest(
  token: string,
  quickReplyId: string,
  payload: {
    departmentName?: string;
    title?: string;
    message?: string;
    isActive?: boolean;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceQuickReplyData>('/attendance/quick-replies/' + quickReplyId, {
    method: 'PATCH',
    token,
    body: payload
  });
}
