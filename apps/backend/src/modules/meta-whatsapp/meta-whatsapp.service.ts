import { Injectable } from '@nestjs/common';
import type {
  MetaListTemplatesInput,
  MetaListTemplatesResult,
  MetaPhoneNumberInfoInput,
  MetaPhoneNumberInfoResult,
  MetaSendMessageResult,
  MetaSendTemplateMessageInput,
  MetaSendTextMessageInput
} from './meta-whatsapp.types';

@Injectable()
export class MetaWhatsappService {
  async sendTextMessage(input: MetaSendTextMessageInput): Promise<MetaSendMessageResult> {
    return this.sendMessageRequest({
      phoneNumberId: input.phoneNumberId,
      accessTokenEncrypted: input.accessTokenEncrypted,
      payload: {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: this.normalizePhone(input.to),
        type: 'text',
        text: {
          preview_url: false,
          body: input.body
        }
      }
    });
  }

  async sendTemplateMessage(
    input: MetaSendTemplateMessageInput
  ): Promise<MetaSendMessageResult> {
    return this.sendMessageRequest({
      phoneNumberId: input.phoneNumberId,
      accessTokenEncrypted: input.accessTokenEncrypted,
      payload: {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: this.normalizePhone(input.to),
        type: 'template',
        template: {
          name: input.templateName,
          language: {
            code: input.languageCode
          }
        }
      }
    });
  }

  async listTemplates(input: MetaListTemplatesInput): Promise<MetaListTemplatesResult> {
    const token = this.decodeAccessToken(input.accessTokenEncrypted);

    if (!token) {
      return {
        success: false,
        statusCode: 0,
        response: {
          error: 'access_token_not_configured'
        },
        errorMessage: 'Token da conta WhatsApp nao configurado'
      };
    }

    const graphVersion = process.env.META_GRAPH_API_VERSION || 'v25.0';
    const fields = 'name,language,status,category,id';
    const url = `https://graph.facebook.com/${graphVersion}/${input.wabaId}/message_templates?fields=${encodeURIComponent(fields)}`;

    return this.getRequest(url, token, 'Erro desconhecido ao listar templates');
  }

  async getPhoneNumberInfo(
    input: MetaPhoneNumberInfoInput
  ): Promise<MetaPhoneNumberInfoResult> {
    const token = this.decodeAccessToken(input.accessTokenEncrypted);

    if (!token) {
      return {
        success: false,
        statusCode: 0,
        response: {
          error: 'access_token_not_configured'
        },
        errorMessage: 'Token da conta WhatsApp nao configurado'
      };
    }

    const graphVersion = process.env.META_GRAPH_API_VERSION || 'v25.0';
    const fields = [
      'id',
      'display_phone_number',
      'verified_name',
      'status',
      'quality_rating',
      'code_verification_status',
      'name_status',
      'messaging_limit_tier'
    ].join(',');
    const url = `https://graph.facebook.com/${graphVersion}/${input.phoneNumberId}?fields=${encodeURIComponent(fields)}`;

    return this.getRequest(url, token, 'Erro desconhecido ao consultar telefone Meta');
  }

  private async getRequest(
    url: string,
    token: string,
    fallbackMessage: string
  ): Promise<MetaListTemplatesResult> {
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      const responseBody = await response.json().catch(() => ({}));

      return {
        success: response.ok,
        statusCode: response.status,
        response: responseBody,
        errorMessage: response.ok ? null : this.extractErrorMessage(responseBody)
      };
    } catch (error) {
      return {
        success: false,
        statusCode: 0,
        response: {
          error: 'network_or_runtime_error'
        },
        errorMessage: error instanceof Error ? error.message : fallbackMessage
      };
    }
  }

  private async sendMessageRequest(input: {
    phoneNumberId: string;
    accessTokenEncrypted: string;
    payload: Record<string, unknown>;
  }): Promise<MetaSendMessageResult> {
    const token = this.decodeAccessToken(input.accessTokenEncrypted);

    if (!token) {
      return {
        success: false,
        providerMessageId: null,
        statusCode: 0,
        response: {
          error: 'access_token_not_configured'
        },
        errorMessage: 'Token da conta WhatsApp nao configurado'
      };
    }

    const graphVersion = process.env.META_GRAPH_API_VERSION || 'v25.0';
    const url = `https://graph.facebook.com/${graphVersion}/${input.phoneNumberId}/messages`;

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(input.payload)
      });

      const responseBody = await response.json().catch(() => ({}));
      const providerMessageId = this.extractProviderMessageId(responseBody);

      if (!response.ok) {
        return {
          success: false,
          providerMessageId,
          statusCode: response.status,
          response: responseBody,
          errorMessage: this.extractErrorMessage(responseBody)
        };
      }

      return {
        success: true,
        providerMessageId,
        statusCode: response.status,
        response: responseBody,
        errorMessage: null
      };
    } catch (error) {
      return {
        success: false,
        providerMessageId: null,
        statusCode: 0,
        response: {
          error: 'network_or_runtime_error'
        },
        errorMessage: error instanceof Error ? error.message : 'Erro desconhecido ao enviar mensagem'
      };
    }
  }

  private decodeAccessToken(value: string): string {
    if (!value || value === 'not_configured') {
      return '';
    }

    try {
      const decoded = Buffer.from(value, 'base64').toString('utf8');

      if (decoded && decoded.trim()) {
        return decoded.trim();
      }
    } catch (_error) {
      return '';
    }

    return '';
  }

  private extractProviderMessageId(responseBody: unknown): string | null {
    const body = responseBody as {
      messages?: Array<{
        id?: string;
      }>;
    };

    const id = body.messages?.[0]?.id;

    if (!id) {
      return null;
    }

    return id;
  }

  private extractErrorMessage(responseBody: unknown): string {
    const body = responseBody as {
      error?: {
        message?: string;
      };
    };

    return body.error?.message || 'Meta retornou erro na chamada';
  }

  private normalizePhone(value: string): string {
    return value.replace(/[^0-9]/g, '');
  }
}
