export type AttendanceAutomationRuleItem = {
  id: string;
  name: string;
  slug: string;
  departmentName: string;
  triggerStatus: string;
  messageOrigin: string;
  messageBody: string;
  isActive: boolean;
  sendDryRun: boolean;
  maxRunsPerConversation: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceAutomationRulesResponse = {
  success: true;
  data: {
    rules: AttendanceAutomationRuleItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceAutomationRuleUpdatePayload = {
  name?: string;
  departmentName?: string;
  triggerStatus?: string;
  messageBody?: string;
  isActive?: boolean;
  sendDryRun?: boolean;
  maxRunsPerConversation?: number;
};

export type AttendanceAutomationRuleResponse = {
  success: true;
  data: {
    rule: AttendanceAutomationRuleItem;
  };
  meta: Record<string, never>;
};

export type AttendanceAutomationRunPayload = {
  conversationId?: string;
  dryRun?: boolean;
  sentByName?: string | null;
};

export type AttendanceAutomationExecutionItem = {
  id: string;
  ruleId: string;
  conversationId: string;
  sendId: string | null;
  status: string;
  dryRun: boolean;
  errorMessage: string | null;
  createdAt: string;
};

export type AttendanceAutomationRunResponse = {
  success: true;
  data: {
    execution: AttendanceAutomationExecutionItem;
  };
  meta: Record<string, never>;
};

export type AttendanceAutomationExecutionsResponse = {
  success: true;
  data: {
    executions: AttendanceAutomationExecutionItem[];
  };
  meta: Record<string, never>;
};
