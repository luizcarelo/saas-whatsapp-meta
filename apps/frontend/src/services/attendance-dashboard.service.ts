import { apiRequest } from './api';
import type { AttendanceDashboardSummary } from '../types/attendance-dashboard.types';

export async function getAttendanceDashboardSummaryRequest(token: string) {
  return apiRequest<AttendanceDashboardSummary>('/attendance-dashboard/summary', {
    method: 'GET',
    token
  });
}
