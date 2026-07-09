#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_43.log"
BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_43_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_43_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_43_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_43_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_43_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_43_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_43_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_43_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_43_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_43_auth_login_domain.log"
DOMAIN_ACCOUNTS_LOG="${LOGS_DIR}/setup_43_whatsapp_accounts_domain.log"
DOMAIN_OPERATIONAL_LOG="${LOGS_DIR}/setup_43_meta_operational_domain.log"
DOMAIN_TEMPLATES_LOG="${LOGS_DIR}/setup_43_meta_templates_domain.log"
DOMAIN_PANEL_LOG="${LOGS_DIR}/setup_43_domain_meta_settings_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_43_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/META_OPERATIONAL_PANEL.md"

DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="https://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ACCOUNTS_URL="${DOMAIN_BASE_URL}/api/v1/whatsapp-accounts"
DOMAIN_PANEL_URL="${DOMAIN_BASE_URL}/app/meta-settings"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Etapa 43: Painel de configuracao operacional da conta Meta =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/meta-whatsapp"
mkdir -p "${FRONTEND_DIR}/src/pages/meta-settings"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.service.ts" \
  "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.types.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts" \
  "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" \
  "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" \
  "${FRONTEND_DIR}/src/pages/meta-settings/MetaSettingsPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERRO: npm nao encontrado."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRO: curl nao encontrado."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ]; then
  echo "ERRO: email admin nao encontrado."
  exit 1
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: senha admin nao encontrada."
  exit 1
fi

echo "Atualizando meta-whatsapp.types.ts..."

cat > "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.types.ts" <<'DOC'
export type MetaSendTextMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  body: string;
};

export type MetaSendTemplateMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  templateName: string;
  languageCode: string;
};

export type MetaSendMessageResult = {
  success: boolean;
  providerMessageId: string | null;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};

export type MetaListTemplatesInput = {
  wabaId: string;
  accessTokenEncrypted: string;
};

export type MetaListTemplatesResult = {
  success: boolean;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};

export type MetaPhoneNumberInfoInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
};

export type MetaPhoneNumberInfoResult = {
  success: boolean;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};
DOC

echo "Atualizando meta-whatsapp.service.ts..."

cat > "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.service.ts" <<'DOC'
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
DOC

echo "Atualizando whatsapp-accounts.types.ts..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts" <<'DOC'
export type WhatsappAccountPayload = {
  wabaId?: string;
  phoneNumberId?: string;
  displayPhoneNumber?: string;
  verifiedName?: string;
  accessToken?: string;
  status?: string;
};

export type WhatsappAccountItem = {
  id: string;
  tenantId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type WhatsappAccountListResponse = {
  success: true;
  data: {
    accounts: WhatsappAccountItem[];
    total: number;
  };
  meta: Record<string, never>;
};

export type WhatsappAccountResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
  };
  meta: Record<string, never>;
};

export type WhatsappAccountDeleteResponse = {
  success: true;
  data: {
    deleted: true;
    id: string;
  };
  meta: Record<string, never>;
};

export type WhatsappTemplateListResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
    templates: unknown;
  };
  meta: Record<string, never>;
};

export type WhatsappOperationalResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
    phoneInfo: unknown;
    templates: unknown;
  };
  meta: Record<string, never>;
};
DOC

echo "Atualizando whatsapp-accounts.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { WhatsappAccountsService } from './whatsapp-accounts.service';
import type { WhatsappAccountPayload } from './whatsapp-accounts.types';

type ListAccountsQuery = {
  search?: string;
  limit?: string;
  offset?: string;
};

@Controller('whatsapp-accounts')
@UseGuards(JwtAuthGuard)
export class WhatsappAccountsController {
  constructor(private readonly whatsappAccountsService: WhatsappAccountsService) {}

  @Get()
  listAccounts(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListAccountsQuery
  ) {
    return this.whatsappAccountsService.listAccounts(user.tenantId, query);
  }

  @Post()
  createAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: WhatsappAccountPayload
  ) {
    return this.whatsappAccountsService.createAccount(user.tenantId, body);
  }

  @Get(':id/templates')
  listTemplates(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.listTemplates(user.tenantId, id);
  }

  @Get(':id/operational')
  getOperationalStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.getOperationalStatus(user.tenantId, id);
  }

  @Get(':id')
  getAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.getAccount(user.tenantId, id);
  }

  @Patch(':id')
  updateAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: WhatsappAccountPayload
  ) {
    return this.whatsappAccountsService.updateAccount(user.tenantId, id, body);
  }

  @Delete(':id')
  deleteAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.deleteAccount(user.tenantId, id);
  }
}
DOC

echo "Atualizando whatsapp-accounts.service.ts com status operacional..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts")
text = path.read_text()

text = text.replace(
    "WhatsappTemplateListResponse\n} from './whatsapp-accounts.types';",
    "WhatsappTemplateListResponse,\n  WhatsappOperationalResponse\n} from './whatsapp-accounts.types';"
)

marker = "  async getAccount(tenantId: string, accountId: string): Promise<WhatsappAccountResponse> {"
if "async getOperationalStatus(" not in text:
    insert = """  async getOperationalStatus(
    tenantId: string,
    accountId: string
  ): Promise<WhatsappOperationalResponse> {
    const account = await this.findAccountOrFail(tenantId, accountId);
    const accessTokenEncrypted = await this.getAccessTokenEncrypted(account.id);

    const phoneInfo = await this.metaWhatsappService.getPhoneNumberInfo({
      phoneNumberId: account.phoneNumberId,
      accessTokenEncrypted
    });

    const templates = await this.metaWhatsappService.listTemplates({
      wabaId: account.wabaId,
      accessTokenEncrypted
    });

    return {
      success: true,
      data: {
        account: this.toItem(account),
        phoneInfo: phoneInfo.response,
        templates: templates.response
      },
      meta: {}
    };
  }

"""
    text = text.replace(marker, insert + marker)

path.write_text(text)
PY

echo "Validando arquivos backend sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/meta-whatsapp" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts"
then
  echo "ERRO: HTML indevido encontrado no backend."
  exit 1
fi

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${BACKEND_TYPECHECK_LOG}"

echo "Rodando build do backend..."

npm run build 2>&1 | tee "${BACKEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Atualizando frontend types..."

cat > "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" <<'DOC'
export type WhatsappAccountItem = {
  id: string;
  tenantId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type WhatsappAccountListData = {
  accounts: WhatsappAccountItem[];
  total: number;
};

export type WhatsappAccountData = {
  account: WhatsappAccountItem;
};

export type WhatsappAccountDeleteData = {
  deleted: true;
  id: string;
};

export type WhatsappAccountFormData = {
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string;
  accessToken: string;
  status: string;
};

export type MetaTemplateItem = {
  id: string;
  name: string;
  language: string;
  status: string;
  category: string;
};

export type MetaTemplatesEnvelope = {
  data?: MetaTemplateItem[];
  paging?: unknown;
};

export type MetaPhoneInfo = {
  id?: string;
  display_phone_number?: string;
  verified_name?: string;
  status?: string;
  quality_rating?: string;
  code_verification_status?: string;
  name_status?: string;
  messaging_limit_tier?: string;
  error?: {
    message?: string;
  };
};

export type WhatsappTemplatesData = {
  account: WhatsappAccountItem;
  templates: MetaTemplatesEnvelope;
};

export type WhatsappOperationalData = {
  account: WhatsappAccountItem;
  phoneInfo: MetaPhoneInfo;
  templates: MetaTemplatesEnvelope;
};
DOC

echo "Atualizando whatsapp-accounts.service.ts frontend..."

cat > "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  WhatsappAccountData,
  WhatsappAccountDeleteData,
  WhatsappAccountFormData,
  WhatsappAccountListData,
  WhatsappOperationalData,
  WhatsappTemplatesData
} from '../types/whatsapp-accounts.types';

export async function listWhatsappAccountsRequest(token: string, search = '') {
  const query = search ? '?search=' + encodeURIComponent(search) : '';

  return apiRequest<WhatsappAccountListData>('/whatsapp-accounts' + query, {
    method: 'GET',
    token
  });
}

export async function listWhatsappTemplatesRequest(token: string, accountId: string) {
  return apiRequest<WhatsappTemplatesData>('/whatsapp-accounts/' + accountId + '/templates', {
    method: 'GET',
    token
  });
}

export async function getWhatsappOperationalRequest(token: string, accountId: string) {
  return apiRequest<WhatsappOperationalData>('/whatsapp-accounts/' + accountId + '/operational', {
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
  return apiRequest<WhatsappAccountDeleteData>('/whatsapp-accounts/' + accountId, {
    method: 'DELETE',
    token
  });
}
DOC

echo "Criando MetaSettingsPage.tsx..."

cat > "${FRONTEND_DIR}/src/pages/meta-settings/MetaSettingsPage.tsx" <<'DOC'
import { useEffect, useMemo, useState } from 'react';
import {
  getWhatsappOperationalRequest,
  listWhatsappAccountsRequest
} from '../../services/whatsapp-accounts.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  MetaPhoneInfo,
  MetaTemplateItem,
  WhatsappAccountItem
} from '../../types/whatsapp-accounts.types';

function statusClass(value?: string) {
  if (value === 'CONNECTED' || value === 'GREEN' || value === 'APPROVED') {
    return 'operational-good';
  }

  if (value === 'YELLOW' || value === 'PENDING_REVIEW') {
    return 'operational-warning';
  }

  if (value === 'RED' || value === 'DECLINED' || value === 'DISCONNECTED') {
    return 'operational-danger';
  }

  return 'operational-neutral';
}

function valueOrEmpty(value?: string) {
  return value && value.trim() ? value : 'Nao informado';
}

export function MetaSettingsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [accounts, setAccounts] = useState<WhatsappAccountItem[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState('');
  const [phoneInfo, setPhoneInfo] = useState<MetaPhoneInfo | null>(null);
  const [templates, setTemplates] = useState<MetaTemplateItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadAccounts() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);

    const response = await listWhatsappAccountsRequest(token);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel carregar contas');
      setLoading(false);
      return;
    }

    const activeAccounts = response.data.accounts.filter((account) => account.status === 'active');
    const ordered = activeAccounts.length > 0 ? activeAccounts : response.data.accounts;

    setAccounts(ordered);

    const preferred = ordered.find((account) => account.phoneNumberId === '1235882016268785')
      || ordered.find((account) => /^[0-9]+$/.test(account.phoneNumberId))
      || ordered[0];

    if (preferred) {
      setSelectedAccountId(preferred.id);
      await loadOperational(preferred.id);
    } else {
      setLoading(false);
    }
  }

  async function loadOperational(accountId: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setMessage('');

    const response = await getWhatsappOperationalRequest(token, accountId);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel consultar a Meta');
      setLoading(false);
      return;
    }

    setPhoneInfo(response.data.phoneInfo);
    setTemplates(response.data.templates.data || []);
    setLoading(false);
  }

  useEffect(() => {
    void loadAccounts();
  }, []);

  const selectedAccount = useMemo(() => {
    return accounts.find((account) => account.id === selectedAccountId) || null;
  }, [accounts, selectedAccountId]);

  const templateSummary = useMemo(() => {
    return {
      total: templates.length,
      approved: templates.filter((template) => template.status === 'APPROVED').length,
      marketing: templates.filter((template) => template.category === 'MARKETING').length,
      utility: templates.filter((template) => template.category === 'UTILITY').length
    };
  }, [templates]);

  async function handleAccountChange(accountId: string) {
    setSelectedAccountId(accountId);
    setLoading(true);
    await loadOperational(accountId);
  }

  async function handleRefresh() {
    if (!selectedAccountId) {
      return;
    }

    setLoading(true);
    await loadOperational(selectedAccountId);
  }

  return (
    <section>
      <div className="page-heading">
        <span>Meta</span>
        <h1>Configuracao operacional</h1>
        <p>Acompanhe a conta WhatsApp ativa, status do numero e templates oficiais.</p>
      </div>

      <div className="meta-settings-toolbar">
        <label>
          Conta WhatsApp
          <select
            onChange={(event) => void handleAccountChange(event.target.value)}
            value={selectedAccountId}
          >
            {accounts.map((account) => (
              <option key={account.id} value={account.id}>
                {account.verifiedName || account.displayPhoneNumber} - {account.phoneNumberId}
              </option>
            ))}
          </select>
        </label>

        <button onClick={() => void handleRefresh()} type="button">
          Atualizar status
        </button>
      </div>

      {message ? <div className="form-message">{message}</div> : null}

      {loading ? (
        <div className="empty-panel">
          <strong>Carregando configuracao operacional...</strong>
          <p>Aguarde enquanto consultamos a Meta.</p>
        </div>
      ) : null}

      {!loading && selectedAccount ? (
        <>
          <div className="meta-operational-grid">
            <article className="meta-operational-card">
              <span>Conta no sistema</span>
              <strong>{selectedAccount.verifiedName || 'Sem nome verificado'}</strong>
              <p>{selectedAccount.displayPhoneNumber}</p>
              <small>Phone Number ID: {selectedAccount.phoneNumberId}</small>
            </article>

            <article className="meta-operational-card">
              <span>Status Meta</span>
              <strong className={statusClass(phoneInfo?.status)}>
                {valueOrEmpty(phoneInfo?.status)}
              </strong>
              <p>Estado atual do numero na Meta.</p>
            </article>

            <article className="meta-operational-card">
              <span>Qualidade</span>
              <strong className={statusClass(phoneInfo?.quality_rating)}>
                {valueOrEmpty(phoneInfo?.quality_rating)}
              </strong>
              <p>Indicador de qualidade reportado pela Meta.</p>
            </article>

            <article className="meta-operational-card">
              <span>Nome verificado</span>
              <strong>{valueOrEmpty(phoneInfo?.verified_name)}</strong>
              <p>Status do nome: {valueOrEmpty(phoneInfo?.name_status)}</p>
            </article>
          </div>

          <div className="meta-operational-grid small">
            <article className="meta-operational-card">
              <span>Templates</span>
              <strong>{templateSummary.total}</strong>
              <p>Total carregado da WABA.</p>
            </article>

            <article className="meta-operational-card">
              <span>Aprovados</span>
              <strong className="operational-good">{templateSummary.approved}</strong>
              <p>Templates prontos para envio.</p>
            </article>

            <article className="meta-operational-card">
              <span>Marketing</span>
              <strong>{templateSummary.marketing}</strong>
              <p>Templates de marketing.</p>
            </article>

            <article className="meta-operational-card">
              <span>Utility</span>
              <strong>{templateSummary.utility}</strong>
              <p>Templates utilitarios.</p>
            </article>
          </div>

          <section className="meta-details-panel">
            <div className="panel-heading">
              <div>
                <h2>Detalhes do numero</h2>
                <p>Dados retornados pela API da Meta.</p>
              </div>
            </div>

            <div className="meta-details-list">
              <div>
                <span>ID</span>
                <strong>{valueOrEmpty(phoneInfo?.id)}</strong>
              </div>

              <div>
                <span>Telefone exibido</span>
                <strong>{valueOrEmpty(phoneInfo?.display_phone_number)}</strong>
              </div>

              <div>
                <span>Verificacao de codigo</span>
                <strong>{valueOrEmpty(phoneInfo?.code_verification_status)}</strong>
              </div>

              <div>
                <span>Limite de mensagens</span>
                <strong>{valueOrEmpty(phoneInfo?.messaging_limit_tier)}</strong>
              </div>
            </div>
          </section>

          <section className="meta-details-panel">
            <div className="panel-heading">
              <div>
                <h2>Templates oficiais</h2>
                <p>Lista de templates retornados da WABA.</p>
              </div>
            </div>

            <div className="meta-template-table">
              {templates.map((template) => (
                <article key={template.id}>
                  <div>
                    <strong>{template.name}</strong>
                    <span>{template.language}</span>
                  </div>

                  <em className={statusClass(template.status)}>{template.status}</em>
                  <small>{template.category}</small>
                </article>
              ))}
            </div>
          </section>
        </>
      ) : null}
    </section>
  );
}
DOC

echo "Atualizando Sidebar..."

cat > "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" <<'DOC'
import { NavLink } from 'react-router-dom';

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="sidebar-logo">LH</div>
        <div>
          <strong>LH Bot</strong>
          <span>WhatsApp Meta</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/app/dashboard">
          Dashboard
        </NavLink>

        <NavLink to="/app/contacts">
          Contatos
        </NavLink>

        <NavLink to="/app/conversations">
          Conversas
        </NavLink>

        <NavLink to="/app/whatsapp-accounts">
          WhatsApp
        </NavLink>

        <NavLink to="/app/meta-settings">
          Meta
        </NavLink>

        <NavLink to="/app/profile">
          Perfil
        </NavLink>
      </nav>
    </aside>
  );
}
DOC

echo "Atualizando routes.tsx..."

cat > "${FRONTEND_DIR}/src/app/routes.tsx" <<'DOC'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes
} from 'react-router-dom';
import { AppLayout } from '../components/layout/AppLayout';
import { ContactsPage } from '../pages/contacts/ContactsPage';
import { ConversationsPage } from '../pages/conversations/ConversationsPage';
import { DashboardPage } from '../pages/dashboard/DashboardPage';
import { LoginPage } from '../pages/login/LoginPage';
import { MetaSettingsPage } from '../pages/meta-settings/MetaSettingsPage';
import { ProfilePage } from '../pages/profile/ProfilePage';
import { WhatsappAccountsPage } from '../pages/whatsapp-accounts/WhatsappAccountsPage';
import { ProtectedRoute } from './ProtectedRoute';

export function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<LoginPage />} />

        <Route
          path="/app"
          element={
            <ProtectedRoute>
              <AppLayout />
            </ProtectedRoute>
          }
        >
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="contacts" element={<ContactsPage />} />
          <Route path="conversations" element={<ConversationsPage />} />
          <Route path="whatsapp-accounts" element={<WhatsappAccountsPage />} />
          <Route path="meta-settings" element={<MetaSettingsPage />} />
          <Route path="profile" element={<ProfilePage />} />
        </Route>

        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
DOC

echo "Adicionando estilos do painel Meta..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.meta-settings-toolbar {
  align-items: end;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  display: grid;
  gap: 16px;
  grid-template-columns: minmax(0, 1fr) auto;
  margin-top: 26px;
  padding: 20px;
}

.meta-settings-toolbar label {
  color: #374151;
  display: grid;
  font-size: 14px;
  font-weight: 800;
  gap: 8px;
}

.meta-settings-toolbar select {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 12px 14px;
}

.meta-settings-toolbar button {
  background: #b91c1c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 18px;
}

.meta-operational-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  margin-top: 22px;
}

.meta-operational-grid.small {
  margin-top: 16px;
}

.meta-operational-card {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  padding: 20px;
}

.meta-operational-card span {
  color: #6b7280;
  display: block;
  font-size: 13px;
  font-weight: 900;
  margin-bottom: 8px;
  text-transform: uppercase;
}

.meta-operational-card strong {
  color: #111827;
  display: block;
  font-size: 24px;
  overflow-wrap: anywhere;
}

.meta-operational-card p {
  color: #6b7280;
  margin: 8px 0 0;
}

.meta-operational-card small {
  color: #6b7280;
  display: block;
  margin-top: 8px;
  overflow-wrap: anywhere;
}

.operational-good {
  color: #15803d !important;
}

.operational-warning {
  color: #a16207 !important;
}

.operational-danger {
  color: #b91c1c !important;
}

.operational-neutral {
  color: #374151 !important;
}

.meta-details-panel {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  margin-top: 22px;
  padding: 22px;
}

.meta-details-list {
  display: grid;
  gap: 12px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.meta-details-list div {
  background: #f9fafb;
  border-radius: 16px;
  padding: 14px;
}

.meta-details-list span {
  color: #6b7280;
  display: block;
  font-size: 12px;
  font-weight: 900;
  margin-bottom: 7px;
  text-transform: uppercase;
}

.meta-details-list strong {
  overflow-wrap: anywhere;
}

.meta-template-table {
  display: grid;
  gap: 10px;
}

.meta-template-table article {
  align-items: center;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) auto auto;
  padding: 14px;
}

.meta-template-table strong {
  display: block;
}

.meta-template-table span,
.meta-template-table small {
  color: #6b7280;
}

.meta-template-table em {
  background: #f3f4f6;
  border-radius: 999px;
  font-style: normal;
  font-weight: 900;
  padding: 7px 10px;
}

@media (max-width: 1100px) {
  .meta-operational-grid,
  .meta-details-list {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 720px) {
  .meta-settings-toolbar,
  .meta-operational-grid,
  .meta-details-list,
  .meta-template-table article {
    grid-template-columns: 1fr;
  }
}
DOC

echo "Validando arquivos frontend sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/pages/meta-settings" \
  "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" \
  "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML indevido encontrado no frontend."
  exit 1
fi

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BACKEND_BUILD_LOG}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo backend, frontend e proxy..."

docker compose up -d backend frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend estabilizar..."

: > "${BACKEND_WAIT_LOG}"

BACKEND_READY="false"

for i in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{.State.Status}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"
  RESTARTING="$(docker inspect -f '{{.State.Restarting}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"

  echo "tentativa=${i} status=${STATUS} restarting=${RESTARTING}" | tee -a "${BACKEND_WAIT_LOG}"

  if [ "${STATUS}" = "running" ] && [ "${RESTARTING}" = "false" ]; then
    if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
      BACKEND_READY="true"
      break
    fi
  fi

  sleep 3
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend nao estabilizou."
  docker compose logs --tail=220 backend 2>&1 | tee "${BACKEND_CRASH_LOG}"
  exit 1
fi

sleep 8

echo "Validando APIs pelo dominio..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

DOMAIN_ACCOUNTS_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_STATUS}" != "200" ]; then
  echo "ERRO: contas dominio falhou. Status ${DOMAIN_ACCOUNTS_STATUS}"
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const accounts=(data.data&&data.data.accounts)||[]; const found=accounts.find((account)=>account.status==='active' && account.phoneNumberId==='1235882016268785') || accounts.find((account)=>account.status==='active' && /^[0-9]+$/.test(account.phoneNumberId)); if(!found){process.exit(2)} console.log(found.id)" "${DOMAIN_ACCOUNTS_LOG}" || true)"

if [ -z "${ACCOUNT_ID}" ]; then
  echo "ERRO: conta Meta ativa nao encontrada."
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

DOMAIN_OPERATIONAL_STATUS="$(curl -L -s -o "${DOMAIN_OPERATIONAL_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}/${ACCOUNT_ID}/operational" || true)"

if [ "${DOMAIN_OPERATIONAL_STATUS}" != "200" ] && [ "${DOMAIN_OPERATIONAL_STATUS}" != "201" ]; then
  echo "ERRO: status operacional falhou. Status ${DOMAIN_OPERATIONAL_STATUS}"
  cat "${DOMAIN_OPERATIONAL_LOG}"
  exit 1
fi

if ! grep -q "quality_rating" "${DOMAIN_OPERATIONAL_LOG}"; then
  echo "ERRO: status operacional nao retornou quality_rating."
  cat "${DOMAIN_OPERATIONAL_LOG}"
  exit 1
fi

DOMAIN_TEMPLATES_STATUS="$(curl -L -s -o "${DOMAIN_TEMPLATES_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}/${ACCOUNT_ID}/templates" || true)"

if [ "${DOMAIN_TEMPLATES_STATUS}" != "200" ] && [ "${DOMAIN_TEMPLATES_STATUS}" != "201" ]; then
  echo "ERRO: templates dominio falhou. Status ${DOMAIN_TEMPLATES_STATUS}"
  cat "${DOMAIN_TEMPLATES_LOG}"
  exit 1
fi

echo "Testando rota meta-settings..."

DOMAIN_PANEL_STATUS="$(curl -L -s -o "${DOMAIN_PANEL_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_PANEL_URL}" || true)"

if [ "${DOMAIN_PANEL_STATUS}" != "200" ]; then
  echo "ERRO: rota meta-settings nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando rota dashboard..."

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: rota dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 43..."

cat > "${DOC_FILE}" <<'DOC'
# Meta Operational Panel

## Visao geral

Este documento registra a criacao do painel de configuracao operacional da conta Meta.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- endpoint de status operacional da conta WhatsApp
- consulta de informacoes do Phone Number ID na Meta
- exibicao de status da conta Meta
- exibicao de quality rating
- exibicao de nome verificado
- exibicao de verificacao de codigo
- exibicao de limite de mensagens quando retornado
- resumo de templates oficiais
- tela frontend em app meta settings
- link Meta na sidebar

## Endpoints criados

Endpoints:

- GET api v1 whatsapp accounts id operational

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.types.ts
- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.service.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts
- apps/frontend/src/types/whatsapp-accounts.types.ts
- apps/frontend/src/services/whatsapp-accounts.service.ts
- apps/frontend/src/pages/meta-settings/MetaSettingsPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/META_OPERATIONAL_PANEL.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- aguardo ativo do backend
- login dominio
- listagem de contas dominio
- status operacional dominio
- listagem de templates dominio
- teste da rota app meta settings
- teste da rota dashboard

## Logs gerados

Logs:

- logs/setup_43_backend_typecheck.log
- logs/setup_43_backend_build.log
- logs/setup_43_frontend_typecheck.log
- logs/setup_43_frontend_build.log
- logs/setup_43_backend_docker_build.log
- logs/setup_43_frontend_docker_build.log
- logs/setup_43_docker_up.log
- logs/setup_43_backend_wait.log
- logs/setup_43_auth_login_domain.log
- logs/setup_43_whatsapp_accounts_domain.log
- logs/setup_43_meta_operational_domain.log
- logs/setup_43_meta_templates_domain.log
- logs/setup_43_domain_meta_settings_page.log
- logs/setup_43_domain_dashboard.log
- logs/setup_43.log

## Proxima etapa sugerida

Etapa 44:

    Criar limpeza operacional das contas de teste e dados artificiais
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Fase 01 - Documentacao inicial

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [x] Etapa 03 - Documentacao de arquitetura
- [x] Etapa 04 - Documentacao do banco de dados
- [x] Etapa 05 - Documentacao da API
- [x] Etapa 06 - Documentacao de seguranca
- [x] Etapa 07 - Documentacao de webhooks da Meta
- [x] Etapa 08 - Documentacao do frontend
- [x] Etapa 09 - Documentacao do backend
- [x] Etapa 10 - Documentacao de deploy
- [x] Etapa 11 - Manifesto final e validacao

## Fase 02 - Estrutura real do projeto

- [x] Etapa 12 - Estrutura de pastas do monorepo
- [x] Etapa 13 - Arquivos base do backend
- [x] Etapa 14 - Arquivos base do frontend
- [x] Etapa 15 - Docker Compose inicial
- [x] Etapa 16 - Arquivo env example
- [x] Etapa 17 - Validacao do ambiente inicial
- [x] Etapa 18 - Instalacao e validacao de dependencias

## Fase 03 - Build e execucao inicial com Docker

- [x] Etapa 19 - Ajustar Dockerfiles e validar build dos containers
- [x] Etapa 20A - Auditoria e backup do Nginx
- [x] Etapa 20B - Configurar Nginx para bot.lhsolucao.com.br
- [x] Etapa 20C - Subir containers e testar dominio

## Fase 04 - Backend real inicial

- [x] Etapa 21 - Health, configuracao e database base
- [x] Etapa 22 - ORM e conexao real com PostgreSQL
- [x] Etapa 23 - Schema inicial do banco com Prisma
- [x] Etapa 24 - Seed inicial de tenant, admin, roles e permissoes
- [x] Etapa 25 - Auth inicial com login real

## Fase 05 - Frontend integrado inicial

- [x] Etapa 26 - Frontend login integrado
- [x] Etapa 27 - Protecao visual de rotas e layout base

## Fase 06 - Usuarios e perfil

- [x] Etapa 28 - Modulo backend de usuarios
- [x] Etapa 29 - Frontend com perfil detalhado

## Fase 07 - Contatos

- [x] Etapa 30 - Modulo backend de contatos
- [x] Etapa 31 - Frontend de contatos integrado

## Fase 08 - Conversas

- [x] Etapa 32 - Frontend de conversas com layout inicial
- [x] Etapa 33 - Modulo backend de conversas
- [x] Etapa 34 - Frontend de conversas integrado ao backend

## Fase 09 - WhatsApp

- [x] Etapa 35 - Modulo backend de WhatsApp Accounts
- [x] Etapa 36 - Frontend de WhatsApp Accounts integrado
- [x] Etapa 37 - Modulo backend de webhooks da Meta
- [x] Etapa 38 - Validacao de assinatura dos webhooks da Meta
- [x] Etapa 39 - Processamento de status no frontend
- [x] Etapa 40 - Envio real pela API oficial da Meta
- [x] Etapa 41 - Templates oficiais da Meta
- [x] Etapa 42 - Frontend para templates oficiais
- [x] Etapa 43 - Painel de configuracao operacional da conta Meta
- [ ] Etapa 44 - Limpeza operacional de dados de teste

## Ultima etapa executada

Etapa 43 - Painel de configuracao operacional da conta Meta.

## Proxima etapa sugerida

Etapa 44 - Criar limpeza operacional das contas de teste e dados artificiais.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo criada.

Backend base criado.

Frontend base criado.

Docker Compose inicial criado.

Env example criado.

Ambiente inicial validado.

Dependencias base instaladas e validadas.

Dockerfiles ajustados e builds validados.

Dominio bot.lhsolucao.com.br configurado e testado.

Backend real inicial iniciado.

Prisma configurado com conexao real ao PostgreSQL.

Schema inicial do banco criado.

Seed inicial criado.

Auth inicial com login real criado.

Frontend login integrado criado.

Layout base e protecao visual de rotas criados.

Modulo backend de usuarios criado.

Frontend com perfil detalhado criado.

Modulo backend de contatos criado.

Frontend de contatos integrado criado.

Frontend de conversas com layout inicial criado.

Modulo backend de conversas criado.

Frontend de conversas integrado ao backend criado.

Modulo backend de WhatsApp Accounts criado.

Frontend de WhatsApp Accounts integrado criado.

Modulo backend de webhooks da Meta criado.

Validacao de assinatura dos webhooks da Meta criada.

Processamento de status de mensagens no frontend criado.

Envio real de mensagens pela API oficial da Meta criado.

Suporte a templates oficiais da Meta criado.

Frontend para envio de templates oficiais criado.

Painel de configuracao operacional da conta Meta criado.

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example
- .env
- .dockerignore

## Documentos tecnicos

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md
- docs/VALIDACAO_FINAL.md
- docs/ESTRUTURA_PROJETO.md
- docs/BACKEND_BASE.md
- docs/FRONTEND_BASE.md
- docs/DOCKER_COMPOSE_BASE.md
- docs/ENV_EXAMPLE.md
- docs/VALIDACAO_AMBIENTE.md
- docs/DEPENDENCIAS_BASE.md
- docs/DOCKER_BUILD.md
- docs/NGINX_BOT_LHSOLUCAO.md
- docs/EXECUCAO_INICIAL_DOMINIO.md
- docs/BACKEND_HEALTH_CONFIG_DATABASE.md
- docs/BACKEND_PRISMA_POSTGRES.md
- docs/PRISMA_SCHEMA_INICIAL.md
- docs/SEED_INICIAL.md
- docs/AUTH_LOGIN_REAL.md
- docs/FRONTEND_LOGIN_INTEGRADO.md
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- docs/BACKEND_USERS_PROFILE.md
- docs/FRONTEND_PROFILE_DETALHADO.md
- docs/BACKEND_CONTACTS.md
- docs/FRONTEND_CONTACTS.md
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- docs/BACKEND_CONVERSATIONS.md
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md
- docs/BACKEND_META_WEBHOOKS.md
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md
- docs/FRONTEND_MESSAGE_STATUS.md
- docs/BACKEND_META_SEND_MESSAGES.md
- docs/BACKEND_META_TEMPLATES.md
- docs/FRONTEND_META_TEMPLATES.md
- docs/META_OPERATIONAL_PANEL.md

## Etapas concluidas

- Etapa 01 ate Etapa 43 concluidas

## Proxima etapa

- Etapa 44 - Limpeza operacional de dados de teste
DOC

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 43
Acao: Painel de configuracao operacional da conta Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Accounts status: ${DOMAIN_ACCOUNTS_STATUS}
Operational status: ${DOMAIN_OPERATIONAL_STATUS}
Templates status: ${DOMAIN_TEMPLATES_STATUS}
Meta settings page status: ${DOMAIN_PANEL_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 43 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/meta-settings"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 44 - Criar limpeza operacional das contas de teste e dados artificiais"
