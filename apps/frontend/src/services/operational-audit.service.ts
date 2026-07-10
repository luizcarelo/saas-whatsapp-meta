import { apiRequest } from './api';
import type {
  AuditHygieneData,
  AuditHygieneRunsData,
  AuditMessagesData,
  AuditRetentionPolicyData,
  AuditSummaryData,
  AuditWebhooksData
} from '../types/operational-audit.types';


export async function listAuditRealHygieneRunsRequest(token: string) {
  return apiRequest<AuditHygieneRunsData>('/operational-audit/hygiene-runs', {
    method: 'GET',
    token
  });
}

export async function getAuditRetentionPolicyRequest(token: string) {
  return apiRequest<AuditRetentionPolicyData>('/operational-audit/retention-policy', {
    method: 'GET',
    token
  });
}

export async function updateAuditRetentionPolicyRequest(token: string, auditRetentionDays: number) {
  return apiRequest<AuditRetentionPolicyData>('/operational-audit/retention-policy', {
    method: 'PATCH',
    token,
    body: {
      auditRetentionDays
    }
  });
}

export async function getAuditSummaryRequest(token: string) {
  return apiRequest<AuditSummaryData>('/operational-audit/summary', {
    method: 'GET',
    token
  });
}

export async function listAuditMessagesRequest(
  token: string,
  filters: {
    status?: string;
    direction?: string;
    type?: string;
  }
) {
  const params = new URLSearchParams();

  if (filters.status) {
    params.set('status', filters.status);
  }

  if (filters.direction) {
    params.set('direction', filters.direction);
  }

  if (filters.type) {
    params.set('type', filters.type);
  }

  params.set('limit', '50');

  return apiRequest<AuditMessagesData>('/operational-audit/messages?' + params.toString(), {
    method: 'GET',
    token
  });
}

export async function listAuditWebhooksRequest(
  token: string,
  filters: {
    status?: string;
    type?: string;
  }
) {
  const params = new URLSearchParams();

  if (filters.status) {
    params.set('status', filters.status);
  }

  if (filters.type) {
    params.set('type', filters.type);
  }

  params.set('limit', '50');

  return apiRequest<AuditWebhooksData>('/operational-audit/webhooks?' + params.toString(), {
    method: 'GET',
    token
  });
}

export async function previewAuditHygieneRequest(token: string, days?: number) {
  const suffix = days ? '?days=' + encodeURIComponent(String(days)) : '';

  return apiRequest<AuditHygieneData>('/operational-audit/hygiene-preview' + suffix, {
    method: 'GET',
    token
  });
}

export async function runAuditHygieneRequest(
  token: string,
  days: number,
  dryRun: boolean
) {
  return apiRequest<AuditHygieneData>('/operational-audit/hygiene-run', {
    method: 'POST',
    token,
    body: {
      days,
      dryRun
    }
  });
}

export async function downloadAuditExportRequest(
  token: string,
  filters: {
    resource: string;
    format: string;
    status?: string;
    direction?: string;
    type?: string;
  }
) {
  const params = new URLSearchParams();

  params.set('resource', filters.resource);
  params.set('format', filters.format);
  params.set('limit', '500');

  if (filters.status) {
    params.set('status', filters.status);
  }

  if (filters.direction) {
    params.set('direction', filters.direction);
  }

  if (filters.type) {
    params.set('type', filters.type);
  }

  const response = await fetch('/api/v1/operational-audit/export?' + params.toString(), {
    method: 'GET',
    headers: {
      Authorization: 'Bearer ' + token
    }
  });

  if (!response.ok) {
    throw new Error('Nao foi possivel exportar o relatorio');
  }

  const blob = await response.blob();
  const disposition = response.headers.get('Content-Disposition') || '';
  const match = disposition.match(/filename="([^"]+)"/);
  const filename = match ? match[1] : 'operational_export.' + filters.format;

  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');

  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();

  window.URL.revokeObjectURL(url);
}


export async function runAuditRealHygieneRequest(
  token: string,
  days: number,
  confirmationPhrase: string
) {
  return apiRequest<AuditHygieneData>('/operational-audit/hygiene-real-run', {
    method: 'POST',
    token,
    body: {
      days,
      confirmationPhrase
    }
  });
}


export async function downloadAuditRealHygieneRunsCsvRequest(token: string) {
  const response = await fetch('/api/v1/operational-audit/hygiene-runs/export', {
    method: 'GET',
    headers: {
      Authorization: 'Bearer ' + token
    }
  });

  if (!response.ok) {
    throw new Error('Nao foi possivel exportar o historico');
  }

  const blob = await response.blob();
  const disposition = response.headers.get('Content-Disposition') || '';
  const match = disposition.match(/filename="([^"]+)"/);
  const filename = match ? match[1] : 'real_hygiene_history.csv';

  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');

  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();

  window.URL.revokeObjectURL(url);
}
