/**
 * Resolves the configured daily paid-analysis limit per user (decision #430).
 *
 * Fails SAFE, never open: an unset, non-numeric, zero, negative, or
 * fractional `SPEECH_ANALYZE_DAILY_LIMIT` value always falls back to
 * {@link DEFAULT_DAILY_LIMIT} rather than disabling quota enforcement. A
 * missing or mistyped env can never mean "unlimited paid analyses".
 *
 * `invalidRaw` is set only when a raw value was actually present but
 * rejected, so the caller can log a single warning; an unset/empty value is
 * normal configuration and never reported as invalid.
 */
export const DEFAULT_DAILY_LIMIT = 60;

export interface DailyLimitResolution {
  /** The limit to enforce: the parsed value, or {@link DEFAULT_DAILY_LIMIT}. */
  readonly limit: number;
  /** The raw env value, only present when it was set but invalid. */
  readonly invalidRaw?: string;
}

export function resolveDailyLimit(raw: string | undefined): DailyLimitResolution {
  const trimmed = raw?.trim();
  if (!trimmed) return { limit: DEFAULT_DAILY_LIMIT };
  const parsed = Number(trimmed);
  if (Number.isInteger(parsed) && parsed > 0) {
    return { limit: parsed };
  }
  return { limit: DEFAULT_DAILY_LIMIT, invalidRaw: trimmed };
}
