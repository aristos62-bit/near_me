import * as vision from '@google-cloud/vision';

// SPoT — Google Cloud Vision SafeSearch client (server-only, ποτέ client-side
// γιατί απαιτεί service-account credentials).
const visionClient = new vision.ImageAnnotatorClient({
  apiEndpoint: 'eu-vision.googleapis.com',
});

export interface ModerationVerdict {
  approved: boolean;
  reasons: string[];
  levels: { adult: string; racy: string; violence: string };
}

// Thresholds: VERY_UNLIKELY < UNLIKELY < POSSIBLE < LIKELY < VERY_LIKELY.
// Adult/Violence: reject LIKELY+ (strict — no explicit content allowed).
// Racy: reject ONLY VERY_LIKELY (χαλαρότερο — POSSIBLE/LIKELY φωτογραφίες
// παραμένουν ορατές, θαμπώνονται μόνο αν ο χρήστης ενεργοποιήσει blur).
const ADULT_VIOLENCE_REJECT = new Set(['LIKELY', 'VERY_LIKELY']);
const RACY_REJECT = new Set(['VERY_LIKELY']);

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
    return { approved: true, reasons: [], levels: { adult: 'UNKNOWN', racy: 'UNKNOWN', violence: 'UNKNOWN' } };
  }
  const reasons: string[] = [];
  if (safe.adult && ADULT_VIOLENCE_REJECT.has(String(safe.adult))) reasons.push('adult');
  if (safe.violence && ADULT_VIOLENCE_REJECT.has(String(safe.violence))) reasons.push('violence');
  if (safe.racy && RACY_REJECT.has(String(safe.racy))) reasons.push('racy');
  return {
    approved: reasons.length === 0,
    reasons,
    levels: {
      adult: String(safe.adult ?? 'UNKNOWN'),
      racy: String(safe.racy ?? 'UNKNOWN'),
      violence: String(safe.violence ?? 'UNKNOWN'),
    },
  };
}