import { apiRequest } from './api';
import type {
  AttendanceClosureData,
  AttendanceClosuresData,
  AttendanceRatingData,
  AttendanceRatingsData
} from '../types/attendance-closure.types';

export async function closeAttendanceConversationRequest(
  token: string,
  conversationId: string,
  payload: {
    closingMessage: string;
    closedByUserId?: string | null;
    closedByName: string;
    departmentName: string;
    ratingRequested: boolean;
  }
) {
  return apiRequest<AttendanceClosureData>('/attendance/conversations/' + conversationId + '/close', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceClosuresRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceClosuresData>('/attendance/conversations/' + conversationId + '/closures', {
    method: 'GET',
    token
  });
}

export async function createAttendanceRatingRequest(
  token: string,
  conversationId: string,
  payload: {
    rating: number;
    comment?: string | null;
  }
) {
  return apiRequest<AttendanceRatingData>('/attendance/conversations/' + conversationId + '/rating', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceRatingsRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceRatingsData>('/attendance/conversations/' + conversationId + '/ratings', {
    method: 'GET',
    token
  });
}
