export type AttendanceClosureItem = {
  id: string;
  conversationId: string;
  closingMessage: string;
  closedByUserId: string | null;
  closedByName: string;
  departmentName: string;
  ratingRequested: boolean;
  createdAt: string;
};

export type AttendanceClosurePayload = {
  closingMessage?: string;
  closedByUserId?: string | null;
  closedByName?: string | null;
  departmentName?: string;
  ratingRequested?: boolean;
};

export type AttendanceClosureResponse = {
  success: true;
  data: {
    closure: AttendanceClosureItem;
  };
  meta: Record<string, never>;
};

export type AttendanceClosuresResponse = {
  success: true;
  data: {
    closures: AttendanceClosureItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceRatingItem = {
  id: string;
  conversationId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
};

export type AttendanceRatingPayload = {
  rating?: number;
  comment?: string | null;
};

export type AttendanceRatingResponse = {
  success: true;
  data: {
    rating: AttendanceRatingItem;
  };
  meta: Record<string, never>;
};

export type AttendanceRatingsResponse = {
  success: true;
  data: {
    ratings: AttendanceRatingItem[];
  };
  meta: Record<string, never>;
};
