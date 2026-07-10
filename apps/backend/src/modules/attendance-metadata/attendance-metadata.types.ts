export type AttendanceInternalNoteItem = {
  id: string;
  conversationId: string;
  note: string;
  createdByUserId: string | null;
  createdByName: string;
  createdAt: string;
};

export type AttendanceInternalNotesResponse = {
  success: true;
  data: {
    notes: AttendanceInternalNoteItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceInternalNotePayload = {
  note?: string;
  createdByUserId?: string | null;
  createdByName?: string | null;
};

export type AttendanceInternalNoteResponse = {
  success: true;
  data: {
    note: AttendanceInternalNoteItem;
  };
  meta: Record<string, never>;
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

export type AttendanceTagsResponse = {
  success: true;
  data: {
    tags: AttendanceTagItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceTagPayload = {
  name?: string;
  color?: string;
};

export type AttendanceTagResponse = {
  success: true;
  data: {
    tag: AttendanceTagItem;
  };
  meta: Record<string, never>;
};

export type AttendanceConversationTagsResponse = {
  success: true;
  data: {
    tags: AttendanceTagItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceAttachTagPayload = {
  tagId?: string;
};
