import { apiRequest } from './api';
import type {
  UserPermissionsData,
  UserProfileData
} from '../types/users.types';

export async function getMyProfileRequest(token: string) {
  return apiRequest<UserProfileData>('/users/me', {
    method: 'GET',
    token
  });
}

export async function getMyPermissionsRequest(token: string) {
  return apiRequest<UserPermissionsData>('/users/me/permissions', {
    method: 'GET',
    token
  });
}
