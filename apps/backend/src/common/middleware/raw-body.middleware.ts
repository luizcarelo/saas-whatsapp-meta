export type RequestWithRawBody = {
  rawBody?: Buffer;
};

export function rawBodySaver(
  request: RequestWithRawBody,
  _response: unknown,
  buffer: Buffer
): void {
  if (buffer && buffer.length > 0) {
    request.rawBody = Buffer.from(buffer);
  }
}
