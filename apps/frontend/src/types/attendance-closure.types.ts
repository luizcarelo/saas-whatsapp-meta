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

export type AttendanceClosureData = {
  closure: AttendanceClosureItem;
};

export type AttendanceClosuresData = {
  closures: AttendanceClosureItem[];
};

export type AttendanceRatingItem = {
  id: string;
  conversationId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
};

export type AttendanceRatingData = {
  rating: AttendanceRatingItem;
};

export type AttendanceRatingsData = {
  ratings: AttendanceRatingItem[];
};
