import { apiRequest } from './api';
import type {
  AttendanceSendFailuresData,
  AttendanceSendRetriesData,
  AttendanceSendRetryData
} from '../types/attendance-send-failures.types';

export async function listAttendanceSendFailuresRequest(token: string) {
  return apiRequest<AttendanceSendFailuresData>('/attendance-send-failures', {
    method: 'GET',
    token
  });
}

export async function retryAttendanceSendFailureRequest(
  token: string,
  sendId: string,
  payload: {
    dryRun: boolean;
    sentByName: string;
  }
) {
  return apiRequest<AttendanceSendRetryData>('/attendance-send-failures/' + sendId + '/retry', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceSendRetriesRequest(token: string) {
  return apiRequest<AttendanceSendRetriesData>('/attendance-send-failures/retries', {
    method: 'GET',
    token
  });
}
