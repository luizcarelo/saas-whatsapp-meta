export type AttendanceDashboardDepartmentMetric = {
  name: string;
  color: string;
  total: number;
  open: number;
  closed: number;
};

export type AttendanceDashboardSummary = {
  conversations: {
    total: number;
    open: number;
    closed: number;
    unassigned: number;
    highPriority: number;
  };
  departments: AttendanceDashboardDepartmentMetric[];
  ratings: {
    total: number;
    average: number;
  };
  activity: {
    notes: number;
    tags: number;
    quickReplies: number;
    closures: number;
  };
};
