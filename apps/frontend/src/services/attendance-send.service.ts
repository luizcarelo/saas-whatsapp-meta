import { apiRequest } from './api';
import type {
  AttendanceSendHistoryData,
  AttendanceSendManualData
} from '../types/attendance-send.types';

export async function sendAttendanceManualMessageRequest(
  token: string,
  conversationId: string,
  payload: {
    messageBody: string;
    sentByUserId?: string | null;
    sentByName: string;
    departmentName: string;
    messageOrigin: string;
    quickReplyId?: string | null;
    quickReplyTitle?: string | null;
    dryRun: boolean;
  }
) {
  return apiRequest<AttendanceSendManualData>('/attendance-send/conversations/' + conversationId + '/messages', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceSendHistoryRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceSendHistoryData>('/attendance-send/conversations/' + conversationId + '/messages', {
    method: 'GET',
    token
  });
}
