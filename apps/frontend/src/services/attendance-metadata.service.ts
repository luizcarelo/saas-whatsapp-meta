import { apiRequest } from './api';
import type {
  AttendanceInternalNoteData,
  AttendanceInternalNotesData,
  AttendanceTagsData
} from '../types/attendance-metadata.types';

export async function listAttendanceTagsRequest(token: string) {
  return apiRequest<AttendanceTagsData>('/attendance/tags', {
    method: 'GET',
    token
  });
}

export async function createAttendanceTagRequest(
  token: string,
  payload: {
    name: string;
    color?: string;
  }
) {
  return apiRequest<AttendanceTagsData>('/attendance/tags', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listConversationNotesRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceInternalNotesData>('/attendance/conversations/' + conversationId + '/notes', {
    method: 'GET',
    token
  });
}

export async function createConversationNoteRequest(
  token: string,
  conversationId: string,
  payload: {
    note: string;
    createdByUserId?: string | null;
    createdByName: string;
  }
) {
  return apiRequest<AttendanceInternalNoteData>('/attendance/conversations/' + conversationId + '/notes', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listConversationTagsRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceTagsData>('/attendance/conversations/' + conversationId + '/tags', {
    method: 'GET',
    token
  });
}

export async function attachConversationTagRequest(
  token: string,
  conversationId: string,
  tagId: string
) {
  return apiRequest<AttendanceTagsData>('/attendance/conversations/' + conversationId + '/tags', {
    method: 'POST',
    token,
    body: {
      tagId
    }
  });
}
