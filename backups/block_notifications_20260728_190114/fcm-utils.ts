import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const RETRYABLE_CODES = new Set([
  'messaging/internal-error',
  'messaging/unavailable',
  'messaging/server-unavailable',
  'messaging/quota-exceeded',
]);

function isRetryable(error: unknown): boolean {
  const err = error as
    | { code?: string; errorInfo?: { code?: string } }
    | undefined;
  if (!err) return false;
  const code = err.code ?? err.errorInfo?.code;
  if (!code) return true;
  if (RETRYABLE_CODES.has(code)) return true;
  if (code.startsWith('messaging/')) return false;
  return true;
}

export async function sendWithRetry(
  payload: admin.messaging.MulticastMessage,
  maxRetries: number = 3,
): Promise<admin.messaging.BatchResponse> {
  let lastError: unknown;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response =
        await admin.messaging().sendEachForMulticast(payload);
      if (attempt > 1) {
        functions.logger.info(
          `FCM send attempt ${attempt}/${maxRetries} succeeded`,
        );
      }
      return response;
    } catch (error) {
      lastError = error;
      const errCode =
        (error as { code?: string; errorInfo?: { code?: string } })
          ?.code ??
        (error as { errorInfo?: { code?: string } })?.errorInfo?.code ??
        'unknown';

      if (!isRetryable(error) || attempt === maxRetries) {
        functions.logger.warn(
          `FCM send attempt ${attempt}/${maxRetries} failed: ${errCode}, no more retries`,
        );
        continue;
      }

      const delayMs = Math.pow(2, attempt - 1) * 1000;
      functions.logger.warn(
        `FCM send attempt ${attempt}/${maxRetries} failed: ${errCode}, retrying in ${delayMs}ms`,
      );
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }

  throw lastError;
}
