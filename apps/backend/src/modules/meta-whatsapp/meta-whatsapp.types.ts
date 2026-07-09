export type MetaSendTextMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  body: string;
};

export type MetaSendTextMessageResult = {
  success: boolean;
  providerMessageId: string | null;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};
