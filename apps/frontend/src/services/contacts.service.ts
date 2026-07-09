import { apiRequest } from './api';
import type {
  ContactData,
  ContactDeleteData,
  ContactFormData,
  ContactListData
} from '../types/contacts.types';

export async function listContactsRequest(token: string, search = '') {
  const query = search ? `?search=${encodeURIComponent(search)}` : '';

  return apiRequest<ContactListData>(`/contacts${query}`, {
    method: 'GET',
    token
  });
}

export async function createContactRequest(token: string, data: ContactFormData) {
  return apiRequest<ContactData>('/contacts', {
    method: 'POST',
    token,
    body: {
      name: data.name,
      phone: data.phone,
      email: data.email,
      document: data.document
    }
  });
}

export async function deleteContactRequest(token: string, contactId: string) {
  return apiRequest<ContactDeleteData>(`/contacts/${contactId}`, {
    method: 'DELETE',
    token
  });
}
