import { apiRequest } from './api';
import type {
  WhatsappAccountData,
  WhatsappAccountDeleteData,
  WhatsappAccountFormData,
  WhatsappAccountListData
} from '../types/whatsapp-accounts.types';

export async function listWhatsappAccountsRequest(token: string, search = '') {
  const query = search ? `?search=${encodeURIComponent(search)}` : '';

  return apiRequest<WhatsappAccountListData>(`/whatsapp-accounts${query}`, {
    method: 'GET',
    token
  });
}

export async function createWhatsappAccountRequest(
  token: string,
  data: WhatsappAccountFormData
) {
  return apiRequest<WhatsappAccountData>('/whatsapp-accounts', {
    method: 'POST',
    token,
    body: {
      wabaId: data.wabaId,
      phoneNumberId: data.phoneNumberId,
      displayPhoneNumber: data.displayPhoneNumber,
      verifiedName: data.verifiedName,
      accessToken: data.accessToken,
      status: data.status
    }
  });
}

export async function deleteWhatsappAccountRequest(token: string, accountId: string) {
  return apiRequest<WhatsappAccountDeleteData>(`/whatsapp-accounts/${accountId}`, {
    method: 'DELETE',
    token
  });
}
