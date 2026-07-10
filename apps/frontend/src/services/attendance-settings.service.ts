import { apiRequest } from './api';

export type AttendanceSettingsDepartment = {
  id: string;
  name: string;
  description?: string | null;
  isActive?: boolean;
};

export type AttendanceSettingsQuickReply = {
  id: string;
  title: string;
  body?: string;
  departmentName?: string | null;
  isActive?: boolean;
};

export type AttendanceSettingsAutomationRule = {
  id: string;
  name: string;
  slug: string;
  departmentName: string;
  triggerStatus: string;
  messageOrigin: string;
  isActive: boolean;
  sendDryRun: boolean;
  maxRunsPerConversation: number;
};

export type AttendanceSettingsStatusItem = {
  id: string;
  group: string;
  code: string;
  label: string;
  description: string;
  sortOrder: number;
  isActive: boolean;
  isTerminal: boolean;
};

export type AttendanceSettingsStatusModel = {
  groups: {
    conversation: AttendanceSettingsStatusItem[];
    attendance: AttendanceSettingsStatusItem[];
    send: AttendanceSettingsStatusItem[];
    closure: AttendanceSettingsStatusItem[];
  };
};

export async function listAttendanceSettingsDepartments(token: string) {
  return apiRequest<{ departments: AttendanceSettingsDepartment[] }>('/attendance/departments', {
    method: 'GET',
    token
  });
}

export async function listAttendanceSettingsQuickReplies(token: string) {
  return apiRequest<{ quickReplies: AttendanceSettingsQuickReply[] }>('/attendance/quick-replies', {
    method: 'GET',
    token
  });
}

export async function listAttendanceSettingsAutomationRules(token: string) {
  return apiRequest<{ rules: AttendanceSettingsAutomationRule[] }>('/attendance-automations/rules', {
    method: 'GET',
    token
  });
}

export async function getAttendanceSettingsStatusModel(token: string) {
  return apiRequest<AttendanceSettingsStatusModel>('/attendance-status/model', {
    method: 'GET',
    token
  });
}
