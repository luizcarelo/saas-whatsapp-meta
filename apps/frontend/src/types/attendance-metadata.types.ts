export type AttendanceInternalNoteItem = {
  id: string;
  conversationId: string;
  note: string;
  createdByUserId: string | null;
  createdByName: string;
  createdAt: string;
};

export type AttendanceInternalNotesData = {
  notes: AttendanceInternalNoteItem[];
};

export type AttendanceInternalNoteData = {
  note: AttendanceInternalNoteItem;
};

export type AttendanceTagItem = {
  id: string;
  name: string;
  slug: string;
  color: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceTagsData = {
  tags: AttendanceTagItem[];
};
