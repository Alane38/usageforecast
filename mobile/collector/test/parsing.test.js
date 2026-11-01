import { describe, expect, test } from "bun:test";
import { BUCKET_MS, buckets, lastActivityAt, merge, prune } from "../lib/ledger.js";
import { parseLine, parseLines } from "../lib/transcripts.js";
import { assistantLine, userLine } from "./fixtures.js";

describe("lecture d'une ligne de journal", () => {
  test("une réponse de l'assistant donne l'heure, le modèle et les quatre compteurs, rien d'autre", () => {
    const record = parseLine(assistantLine());
    expect(record).toEqual({ key: "msg_1:req_1", t: Date.parse("2026-11-01T10:02:00.000Z"), model: "claude-opus-5-5", in: 10, out: 20, cw: 30, cr: 40 });
  });

  test("ignorées : message de l'utilisateur, JSON invalide, ligne vide, sans heure, sans usage, synthétique, tout à zéro", () => {
    expect(parseLine(userLine())).toBeNull();
    expect(parseLine("{pas du json")).toBeNull();
    expect(parseLine("")).toBeNull();
    expect(parseLine(assistantLine({ at: "pas une date" }))).toBeNull();
    expect(parseLine(JSON.stringify({ type: "assistant", timestamp: "2026-11-01T10:00:00Z", message: { id: "m" } }))).toBeNull();
    expect(parseLine(assistantLine({ model: "<synthetic>" }))).toBeNull();
    expect(parseLine(assistantLine({ input: 0, output: 0, cacheWrite: 0, cacheRead: 0 }))).toBeNull();
  });

  test("compteurs absents, négatifs ou non numériques : comptés zéro", () => {
    const line = JSON.parse(assistantLine());
    line.message.usage = { output_tokens: 5, input_tokens: -3, cache_read_input_tokens: "12" };
    expect(parseLine(JSON.stringify(line))).toMatchObject({ in: 0, out: 5, cw: 0, cr: 0 });
  });

  test("plusieurs lignes mêlées", () => {
    const text = [userLine(), assistantLine({ id: "a" }), "", assistantLine({ id: "b" })].join("\n");
    expect(parseLines(text).map((record) => record.key)).toEqual(["a:req_1", "b:req_1"]);
  });
});

describe("registre et tranches de 5 minutes", () => {
  test("une réponse écrite deux fois pendant le streaming n'est comptée qu'une fois, avec ses compteurs finaux", () => {
    const messages = {};
    const partial = parseLine(assistantLine({ output: 1 }));
    const final = parseLine(assistantLine({ output: 300 }));
    expect(merge(messages, [partial])).toBe(1);
    expect(merge(messages, [final, partial])).toBe(0);
    expect(Object.keys(messages)).toHaveLength(1);
    expect(messages["msg_1:req_1"].out).toBe(300);
  });

  test("même message, requête différente : deux réponses", () => {
    const messages = {};
    merge(messages, [parseLine(assistantLine({ requestId: "r1" })), parseLine(assistantLine({ requestId: "r2" }))]);
    expect(Object.keys(messages)).toHaveLength(2);
  });

  test("tranches : début arrondi aux 5 minutes, totaux et tokens par modèle", () => {
    const messages = {};
    merge(messages, [
      parseLine(assistantLine({ id: "a", at: "2026-11-01T10:01:00Z", model: "claude-opus-5-5" })),
      parseLine(assistantLine({ id: "b", at: "2026-11-01T10:04:59Z", model: "claude-sonnet-5-5" })),
      parseLine(assistantLine({ id: "c", at: "2026-11-01T10:05:00Z" })),
    ]);
    const result = buckets(messages);
    expect(result).toHaveLength(2);
    expect(result[0]).toEqual({ t: Date.parse("2026-11-01T10:00:00Z") / 1000, n: 2, in: 20, out: 40, cw: 60, cr: 80, models: { "claude-opus-5-5": 100, "claude-sonnet-5-5": 100 } });
    expect(result[1].t - result[0].t).toBe(BUCKET_MS / 1000);
    expect(lastActivityAt(messages)).toBe(Date.parse("2026-11-01T10:05:00Z"));
  });

  test("ce qui a plus de 8 jours est oublié", () => {
    const messages = {};
    merge(messages, [parseLine(assistantLine({ id: "vieux", at: "2026-10-20T10:00:00Z" })), parseLine(assistantLine({ id: "recent", at: "2026-10-31T10:00:00Z" }))]);
    prune(messages, Date.parse("2026-11-01T10:00:00Z"));
    expect(Object.keys(messages)).toEqual(["recent:req_1"]);
    expect(lastActivityAt({})).toBeNull();
  });
});
