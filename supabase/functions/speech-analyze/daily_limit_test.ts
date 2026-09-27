import { assertEquals } from "jsr:@std/assert@1.0.19";
import { DEFAULT_DAILY_LIMIT, resolveDailyLimit } from "./daily_limit.ts";

Deno.test("unset env resolves to the default limit, no warning reported", () => {
  assertEquals(resolveDailyLimit(undefined), { limit: DEFAULT_DAILY_LIMIT });
});

Deno.test("empty or whitespace-only env resolves to the default limit, no warning reported", () => {
  assertEquals(resolveDailyLimit(""), { limit: DEFAULT_DAILY_LIMIT });
  assertEquals(resolveDailyLimit("   "), { limit: DEFAULT_DAILY_LIMIT });
});

Deno.test("a valid positive integer is used as-is", () => {
  assertEquals(resolveDailyLimit("60"), { limit: 60 });
  assertEquals(resolveDailyLimit(" 25 "), { limit: 25 });
  assertEquals(resolveDailyLimit("1"), { limit: 1 });
});

Deno.test("non-numeric, zero, negative, or fractional values fail safe to the default and are reported", () => {
  assertEquals(resolveDailyLimit("abc"), { limit: DEFAULT_DAILY_LIMIT, invalidRaw: "abc" });
  assertEquals(resolveDailyLimit("0"), { limit: DEFAULT_DAILY_LIMIT, invalidRaw: "0" });
  assertEquals(resolveDailyLimit("-5"), { limit: DEFAULT_DAILY_LIMIT, invalidRaw: "-5" });
  assertEquals(resolveDailyLimit("12.5"), { limit: DEFAULT_DAILY_LIMIT, invalidRaw: "12.5" });
  assertEquals(
    resolveDailyLimit("Infinity"),
    { limit: DEFAULT_DAILY_LIMIT, invalidRaw: "Infinity" },
  );
  assertEquals(resolveDailyLimit("NaN"), { limit: DEFAULT_DAILY_LIMIT, invalidRaw: "NaN" });
});
