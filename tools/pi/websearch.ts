/**
 * Web Search Tool - Search the web via Kagi and fetch page contents
 *
 * Provides two tools:
 * - websearch: Search the web via Kagi (uses kagi-search CLI with rbw for auth)
 * - webfetch: Fetch and extract text content from a URL
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

interface KagiOutput {
  results: SearchResult[];
  quick_answer?: {
    markdown: string;
    raw_text: string;
    references: { title: string; url: string; contribution: string }[];
  };
}

export default function websearch(pi: ExtensionAPI) {
  pi.registerTool({
    name: "websearch",
    label: "Web Search",
    description:
      "Search the web using Kagi. Returns a quick answer (AI summary) and search result links. Use this when you need to find current information online.",
    promptSnippet: "Search the web via Kagi for current information",
    parameters: Type.Object({
      query: Type.String({ description: "Search query" }),
      num_results: Type.Optional(
        Type.Number({
          description: "Number of link results to return (default: 5)",
        }),
      ),
    }),

    async execute(_toolCallId, params, signal) {
      const numResults = params.num_results ?? 5;
      const result = await pi.exec(
        "kagi-search",
        [
          "--json",
          "--links",
          "--num-results",
          String(numResults),
          params.query,
        ],
        { signal, timeout: 30000 },
      );

      if (result.code !== 0) {
        throw new Error(
          `kagi-search failed (exit ${result.code}): ${result.stderr}`,
        );
      }

      let output: KagiOutput;
      try {
        output = JSON.parse(result.stdout);
      } catch {
        throw new Error(
          `Failed to parse kagi-search output: ${result.stdout.slice(0, 200)}`,
        );
      }

      const parts: string[] = [];

      if (output.quick_answer) {
        parts.push("## Quick Answer\n");
        parts.push(
          output.quick_answer.markdown || output.quick_answer.raw_text,
        );
        if (output.quick_answer.references?.length) {
          parts.push("\n\n### References");
          for (const ref of output.quick_answer.references) {
            parts.push(`- [${ref.title}](${ref.url}) (${ref.contribution})`);
          }
        }
      }

      if (output.results?.length) {
        parts.push("\n\n## Search Results\n");
        for (const [i, r] of output.results.entries()) {
          parts.push(`${i + 1}. ${r.title}\n   ${r.url}\n   ${r.snippet}`);
        }
      }

      if (
        !output.quick_answer &&
        (!output.results || output.results.length === 0)
      ) {
        return {
          content: [
            { type: "text", text: "No results found for: " + params.query },
          ],
          details: { query: params.query, results: [], quick_answer: null },
        };
      }

      return {
        content: [{ type: "text", text: parts.join("\n") }],
        details: { query: params.query, ...output },
      };
    },

    renderCall(args, theme) {
      let text = theme.fg("toolTitle", theme.bold("websearch "));
      text += theme.fg("accent", `"${args.query}"`);
      if (args.num_results) {
        text += theme.fg("dim", ` (${args.num_results} results)`);
      }
      return new Text(text, 0, 0);
    },

    renderResult(result, _options, theme) {
      const details = result.details as
        | (KagiOutput & { query: string })
        | undefined;
      if (!details) {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "", 0, 0);
      }

      const lines: string[] = [];

      if (details.quick_answer) {
        lines.push(theme.fg("accent", theme.bold("Quick Answer")));
        const preview =
          details.quick_answer.markdown?.slice(0, 300) ||
          details.quick_answer.raw_text?.slice(0, 300) ||
          "";
        lines.push(
          theme.fg("text", preview + (preview.length >= 300 ? "..." : "")),
        );
      }

      if (details.results?.length) {
        if (lines.length) lines.push("");
        for (const r of details.results) {
          lines.push(
            `${theme.fg("accent", r.title)}\n  ${theme.fg("dim", r.url)}\n  ${theme.fg("muted", r.snippet)}`,
          );
        }
      }

      if (!lines.length) {
        return new Text(theme.fg("warning", "No results found"), 0, 0);
      }

      return new Text(lines.join("\n"), 0, 0);
    },
  });

  pi.registerTool({
    name: "webfetch",
    label: "Web Fetch",
    description:
      "Fetch a web page and extract its text content. Use this to read the contents of a specific URL found via websearch or provided by the user.",
    promptSnippet: "Fetch and read the text content of a web page URL",
    parameters: Type.Object({
      url: Type.String({ description: "URL to fetch" }),
    }),

    async execute(_toolCallId, params, signal) {
      const result = await pi.exec(
        "bash",
        [
          "-c",
          `curl -sL --max-time 15 --max-filesize 2097152 -H 'User-Agent: Mozilla/5.0' ${JSON.stringify(params.url)} | sed -e 's/<script[^>]*>.*<\\/script>//g' -e 's/<style[^>]*>.*<\\/style>//g' -e 's/<[^>]*>//g' -e '/^[[:space:]]*$/d' | head -c 50000`,
        ],
        { signal, timeout: 20000 },
      );

      if (result.code !== 0) {
        throw new Error(
          `Failed to fetch URL (exit ${result.code}): ${result.stderr}`,
        );
      }

      const content = result.stdout.trim();
      if (!content) {
        throw new Error("No content extracted from URL: " + params.url);
      }

      return {
        content: [{ type: "text", text: content }],
        details: { url: params.url, length: content.length },
      };
    },

    renderCall(args, theme) {
      let text = theme.fg("toolTitle", theme.bold("webfetch "));
      text += theme.fg("accent", args.url as string);
      return new Text(text, 0, 0);
    },

    renderResult(result, _options, theme) {
      const details = result.details as
        | { url: string; length: number }
        | undefined;
      if (!details) {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "", 0, 0);
      }
      const preview =
        result.content[0]?.type === "text"
          ? result.content[0].text.slice(0, 200) + "..."
          : "";
      return new Text(
        `${theme.fg("success", "✓")} ${theme.fg("dim", details.url)} ${theme.fg("muted", `(${details.length} chars)`)}\n${theme.fg("muted", preview)}`,
        0,
        0,
      );
    },
  });
}
