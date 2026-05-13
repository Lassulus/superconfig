/**
 * Ollama provider — auto-discover models from a remote Ollama server.
 *
 * Queries the Ollama `/api/tags` endpoint at startup and registers every
 * model it returns under a single provider, talking via Ollama's OpenAI
 * compatibility layer (`/v1/chat/completions`).
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const ENDPOINTS: { name: string; host: string }[] = [
  { name: "c-base", host: "http://neoprism.r:11434" },
];

const DISCOVERY_TIMEOUT_MS = 3000;

interface OllamaTag {
  name: string;
  model: string;
  details?: {
    parameter_size?: string;
    family?: string;
  };
}

async function fetchTags(host: string): Promise<OllamaTag[]> {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), DISCOVERY_TIMEOUT_MS);
  try {
    const res = await fetch(`${host}/api/tags`, { signal: ctl.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = (await res.json()) as { models?: OllamaTag[] };
    return body.models ?? [];
  } finally {
    clearTimeout(timer);
  }
}

export default async function ollama(pi: ExtensionAPI) {
  for (const { name, host } of ENDPOINTS) {
    let tags: OllamaTag[];
    try {
      tags = await fetchTags(host);
    } catch (err) {
      console.error(
        `[ollama] discovery failed for ${host}: ${err instanceof Error ? err.message : err}`,
      );
      continue;
    }

    if (tags.length === 0) continue;

    const providerName = ENDPOINTS.length === 1 ? "ollama" : `ollama-${name}`;

    pi.registerProvider(providerName, {
      name: `Ollama (${name})`,
      baseUrl: `${host}/v1`,
      apiKey: "ollama",
      api: "openai-completions",
      models: tags.map((t) => ({
        id: t.model,
        name: t.details?.parameter_size
          ? `${t.model} (${t.details.parameter_size})`
          : t.model,
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 32768,
        maxTokens: 8192,
      })),
    });
  }
}
