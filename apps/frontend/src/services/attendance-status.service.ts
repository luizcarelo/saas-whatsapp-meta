import { apiRequest } from './api';
import type {
  AttendanceStatusCompatibilityMapData,
  AttendanceStatusModelData,
  AttendanceStatusOptionsData
} from '../types/attendance-status.types';

export async function getAttendanceStatusModelRequest(token: string) {
  return apiRequest<AttendanceStatusModelData>('/attendance-status/model', {
    method: 'GET',
    token
  });
}

export async function getAttendanceStatusOptionsRequest(
  token: string,
  group: string
) {
  return apiRequest<AttendanceStatusOptionsData>('/attendance-status/options?group=' + encodeURIComponent(group), {
    method: 'GET',
    token
  });
}

export async function getAttendanceStatusCompatibilityMapRequest(token: string) {
  return apiRequest<AttendanceStatusCompatibilityMapData>('/attendance-status/compatibility-map', {
    method: 'GET',
    token
  });
}
