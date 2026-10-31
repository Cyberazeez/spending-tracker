import assert from "node:assert/strict";
import { normalizeMerchant } from "./normalize.ts";

Deno.test("normalizeMerchant: case, punctuation and spacing", () => {
  assert.equal(normalizeMerchant("  MYSR*Jahez "), "mysr jahez");
  assert.equal(normalizeMerchant("HUNGERSTATION  LLC"), "hungerstation llc");
});

Deno.test("normalizeMerchant: Arabic diacritics, tatweel and letter variants fold together", () => {
  assert.equal(normalizeMerchant("مَطْعَم"), normalizeMerchant("مطعم"));
  assert.equal(normalizeMerchant("أسواق"), normalizeMerchant("اسواق"));
  assert.equal(normalizeMerchant("بقالـــة"), normalizeMerchant("بقاله"));
  assert.equal(normalizeMerchant("مستشفى"), normalizeMerchant("مستشفي"));
});

Deno.test("normalizeMerchant: Arabic-Indic digits become ASCII", () => {
  assert.equal(normalizeMerchant("فرع ١٢"), "فرع 12");
});
