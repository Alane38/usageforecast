// Lignes de journal Claude Code fabriquées pour les tests (format observé : une ligne JSON par événement).

export const PRIVATE_TEXT = "TEXTE-PRIVE-NE-DOIT-JAMAIS-SORTIR";

export function assistantLine({ id = "msg_1", requestId = "req_1", at = "2026-11-01T10:02:00.000Z", model = "claude-opus-5-5", input = 10, output = 20, cacheWrite = 30, cacheRead = 40, text = PRIVATE_TEXT } = {}) {
  return JSON.stringify({
    type: "assistant",
    uuid: `uuid-${id}`,
    requestId,
    timestamp: at,
    cwd: "/home/sam/projets/secret-client",
    message: {
      id,
      model,
      role: "assistant",
      content: [{ type: "text", text }],
      usage: { input_tokens: input, output_tokens: output, cache_creation_input_tokens: cacheWrite, cache_read_input_tokens: cacheRead },
    },
  });
}

export function userLine(text = PRIVATE_TEXT, at = "2026-11-01T10:01:00.000Z") {
  return JSON.stringify({ type: "user", timestamp: at, message: { role: "user", content: text } });
}
