import * as vision from '@google-cloud/vision';

// SPoT — Google Cloud Vision SafeSearch client (server-only, ποτέ client-side
// γιατί απαιτεί service-account credentials).
const visionClient = new vision.ImageAnnotatorClient({
  apiEndpoint: 'eu-vision.googleapis.com',
});

export interface ModerationVerdict {
  approved: boolean;
  reasons: string[];
}

// Thresholds: VERY_UNLIKELY < UNLIKELY < POSSIBLE < LIKELY < VERY_LIKELY.
// Απορρίπτουμε μόνο LIKELY+ για adult/violence/racy — αποφυγή false-positives
// σε φυσιολογικές φωτογραφίες προφίλ (π.χ. παραλία → racy=POSSIBLE είναι OK).
const REJECT_LEVELS = new Set(['LIKELY', 'VERY_LIKELY']);

/**
 * Τρέχει Google Cloud Vision SafeSearch πάνω σε inline εικόνα (base64).
 * Πετάει exception σε σφάλμα — ο caller (index.ts) αποφασίζει το fallback.
 */
export async function runSafeSearch(base64Image: string): Promise<ModerationVerdict> {
  return runSafeSearchOnImage({ content: base64Image });
}

/**
 * Τρέχει Google Cloud Vision SafeSearch πάνω σε αρχείο ήδη στο Storage,
 * μέσω gs:// URI — χρησιμοποιείται από το server-side onFinalize backstop
 * (δεν χρειάζεται να κατεβάσουμε/κωδικοποιήσουμε bytes, το Vision διαβάζει
 * απευθείας από το bucket με το service-account του project).
 */
export async function runSafeSearchGcs(gcsUri: string): Promise<ModerationVerdict> {
  return runSafeSearchOnImage({ source: { imageUri: gcsUri } });
}

async function runSafeSearchOnImage(
  image: { content: string } | { source: { imageUri: string } },
): Promise<ModerationVerdict> {
  const [result] = await visionClient.safeSearchDetection({ image });
  const safe = result.safeSearchAnnotation;
  if (!safe) {
    return { approved: true, reasons: [] };
  }
  const reasons: string[] = [];
  if (safe.adult && REJECT_LEVELS.has(String(safe.adult))) reasons.push('adult');
  if (safe.violence && REJECT_LEVELS.has(String(safe.violence))) reasons.push('violence');
  if (safe.racy && REJECT_LEVELS.has(String(safe.racy))) reasons.push('racy');
  return { approved: reasons.length === 0, reasons };
}