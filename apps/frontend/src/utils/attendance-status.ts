export type AttendanceStatusGroup =
  | 'conversation'
  | 'attendance'
  | 'send'
  | 'closure';

type StatusLabelMap = Record<string, string>;

const conversationLabels: StatusLabelMap = {
  open: 'Aberta',
  closed: 'Fechada',
  archived: 'Arquivada',
  human: 'Aberta'
};

const attendanceLabels: StatusLabelMap = {
  novo: 'Novo',
  em_atendimento: 'Em atendimento',
  'em atendimento': 'Em atendimento',
  aguardando_cliente: 'Aguardando cliente',
  'aguardando cliente': 'Aguardando cliente',
  aguardando_atendente: 'Aguardando atendente',
  encerrado: 'Encerrado',
  arquivado: 'Arquivado'
};

const sendLabels: StatusLabelMap = {
  pending: 'Pendente',
  sent: 'Enviado',
  delivered: 'Entregue',
  read: 'Lida',
  failed: 'Falhou',
  dry_run: 'Simulacao',
  'dry run': 'Simulacao'
};

const closureLabels: StatusLabelMap = {
  closure_created: 'Encerramento criado',
  rating_requested: 'Avaliacao solicitada',
  rating_received: 'Avaliacao recebida',
  rating_not_received: 'Avaliacao nao recebida'
};

export function normalizeAttendanceStatus(
  group: AttendanceStatusGroup,
  status: string | null | undefined
) {
  const value = (status || '').trim();

  if (!value) {
    return '';
  }

  const lower = value.toLowerCase();

  if (group === 'conversation') {
    if (lower === 'human') {
      return 'open';
    }

    return lower;
  }

  if (group === 'attendance') {
    if (lower === 'em atendimento') {
      return 'em_atendimento';
    }

    if (lower === 'aguardando cliente') {
      return 'aguardando_cliente';
    }

    return lower;
  }

  if (group === 'send') {
    if (lower === 'dry run') {
      return 'dry_run';
    }

    return lower;
  }

  return lower;
}

export function getAttendanceStatusLabel(
  group: AttendanceStatusGroup,
  status: string | null | undefined
) {
  const original = (status || '').trim();

  if (!original) {
    return 'Nao informado';
  }

  const normalized = normalizeAttendanceStatus(group, original);

  if (group === 'conversation') {
    return conversationLabels[normalized] || conversationLabels[original] || original;
  }

  if (group === 'attendance') {
    return attendanceLabels[normalized] || attendanceLabels[original] || original;
  }

  if (group === 'send') {
    return sendLabels[normalized] || sendLabels[original] || original;
  }

  return closureLabels[normalized] || closureLabels[original] || original;
}

export function isTerminalAttendanceStatus(
  group: AttendanceStatusGroup,
  status: string | null | undefined
) {
  const normalized = normalizeAttendanceStatus(group, status);

  if (group === 'conversation') {
    return normalized === 'closed' || normalized === 'archived';
  }

  if (group === 'attendance') {
    return normalized === 'encerrado' || normalized === 'arquivado';
  }

  if (group === 'send') {
    return normalized === 'failed' || normalized === 'dry_run' || normalized === 'read';
  }

  return normalized === 'rating_received';
}
