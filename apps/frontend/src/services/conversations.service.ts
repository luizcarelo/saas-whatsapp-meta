import { apiRequest } from './api';
import type {
  ConversationData,
  ConversationFormData,
  ConversationListData,
  ConversationMessageData
} from '../types/conversations.types';

export async function listConversationsRequest(token: string, search = '') {
  const query = search ? `?search=${encodeURIComponent(search)}` : '';

  return apiRequest<ConversationListData>(`/conversations${query}`, {
    method: 'GET',
    token
  });
}

export async function createConversationRequest(token: string, data: ConversationFormData) {
  return apiRequest<ConversationData>('/conversations', {
    method: 'POST',
    token,
    body: {
      name: data.name,
      phone: data.phone,
      initialMessage: data.initialMessage
    }
  });
}

export async function getConversationRequest(token: string, conversationId: string) {
  return apiRequest<ConversationData>(`/conversations/${conversationId}`, {
    method: 'GET',
    token
  });
}

export async function createConversationMessageRequest(
  token: string,
  conversationId: string,
  body: string
) {
  return apiRequest<ConversationMessageData>(`/conversations/${conversationId}/messages`, {
    method: 'POST',
    token,
    body: {
      body
    }
  });
}

export async function closeConversationRequest(token: string, conversationId: string) {
  return apiRequest<ConversationData>(`/conversations/${conversationId}/close`, {
    method: 'PATCH',
    token
  });
}
