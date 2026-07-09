import { Injectable } from '@nestjs/common';
import type {
  MetaSendTextMessageInput,
  MetaSendTextMessageResult
} from './meta-whatsapp.types';

@Injectable()
export class MetaWhatsappService {
  async sendTextMessage(input: MetaSendTextMessageInput): Promise<MetaSendTextMessageResult> {
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

    const payload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: this.normalizePhone(input.to),
      type: 'text',
      text: {
        preview_url: false,
        body: input.body
      }
    };

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
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

    return body.error?.message || 'Meta retornou erro no envio da mensagem';
  }

  private normalizePhone(value: string): string {
    return value.replace(/[^0-9]/g, '');
  }
}
