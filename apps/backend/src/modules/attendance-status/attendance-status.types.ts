export type AttendanceStatusGroup =
  | 'conversation'
  | 'attendance'
  | 'send'
  | 'closure';

export type AttendanceStatusCatalogItem = {
  id: string;
  group: string;
  code: string;
  label: string;
  description: string;
  sortOrder: number;
  isActive: boolean;
  isTerminal: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceStatusCompatibilityItem = {
  id: string;
  legacyScope: string;
  legacyStatus: string;
  targetGroup: string;
  targetStatus: string;
  notes: string;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceStatusModelResponse = {
  success: true;
  data: {
    groups: {
      conversation: AttendanceStatusCatalogItem[];
      attendance: AttendanceStatusCatalogItem[];
      send: AttendanceStatusCatalogItem[];
      closure: AttendanceStatusCatalogItem[];
    };
  };
  meta: Record<string, never>;
};

export type AttendanceStatusOptionsResponse = {
  success: true;
  data: {
    options: AttendanceStatusCatalogItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceStatusCompatibilityMapResponse = {
  success: true;
  data: {
    mappings: AttendanceStatusCompatibilityItem[];
  };
  meta: Record<string, never>;
};
