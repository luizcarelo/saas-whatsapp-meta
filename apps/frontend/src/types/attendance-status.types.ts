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

export type AttendanceStatusModelData = {
  groups: {
    conversation: AttendanceStatusCatalogItem[];
    attendance: AttendanceStatusCatalogItem[];
    send: AttendanceStatusCatalogItem[];
    closure: AttendanceStatusCatalogItem[];
  };
};

export type AttendanceStatusOptionsData = {
  options: AttendanceStatusCatalogItem[];
};

export type AttendanceStatusCompatibilityMapData = {
  mappings: AttendanceStatusCompatibilityItem[];
};
