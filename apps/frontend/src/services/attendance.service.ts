import { apiRequest } from './api';
import type {
  AttendanceConversationListData,
  AttendanceDepartmentData,
  AttendanceDepartmentsData,
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
