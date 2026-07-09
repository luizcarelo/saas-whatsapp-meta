export type MetaSendTextMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  body: string;
};

export type MetaSendTemplateMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  templateName: string;
  languageCode: string;
};

export type MetaSendMessageResult = {
  success: boolean;
  providerMessageId: string | null;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};

export type MetaListTemplatesInput = {
  wabaId: string;
  accessTokenEncrypted: string;
};

export type MetaListTemplatesResult = {
  success: boolean;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};

export type MetaPhoneNumberInfoInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
};

export type MetaPhoneNumberInfoResult = {
  success: boolean;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};
