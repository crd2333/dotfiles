import { homedir } from "node:os";
import { isAbsolute, relative, sep } from "node:path";
import type { Usage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, SessionEntry } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

function tokens(count: number): string {
  if (count < 1_000) return String(count);
  if (count < 10_000) return `${(count / 1_000).toFixed(1)}k`;
  if (count < 1_000_000) return `${Math.round(count / 1_000)}k`;
  if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
  return `${Math.round(count / 1_000_000)}M`;
}

function summarize(entries: readonly SessionEntry[]) {
  let promptTotal = 0, cacheReadTotal = 0, cost = 0;
  let latest: number | undefined;
  function add(usage: Usage) {
    const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
    promptTotal += prompt;
    cacheReadTotal += usage.cacheRead;
    cost += usage.cost.total;
    return prompt > 0 ? 100 * usage.cacheRead / prompt : undefined;
  }
  for (const entry of entries) {
    if (entry.type === "message") {
      const message = entry.message;
      if (message.role === "assistant") latest = add(message.usage);
      else if (message.role === "toolResult" && message.usage) add(message.usage);
    } else if ((entry.type === "usage" || entry.type === "compaction" || entry.type === "branch_summary") && entry.usage) {
      add(entry.usage);
    }
  }
  return { latest, lifetime: promptTotal > 0 ? 100 * cacheReadTotal / promptTotal : undefined, cost };
}

function displayPath(cwd: string): string {
  const fromHome = relative(homedir(), cwd);
  if (!fromHome) return "~";
  return isAbsolute(fromHome) || fromHome === ".." || fromHome.startsWith(`..${sep}`) ? cwd : `~${sep}${fromHome}`;
}

const dot = " · ";
const join = (...parts: string[]) => parts.filter(Boolean).join(dot);
const clean = (text: string) => text.replace(/[\r\n\t]/g, " ");
const rate = (value: number | undefined) => value === undefined ? "" : `${value.toFixed(1)}%`;

function fit(text: string, width: number): string {
  return width > 1 ? truncateToWidth(text, width, "…") : "";
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    const session = ctx.sessionManager;
    const id = session.getSessionFile() ? session.getSessionId() : "";
    const cwd = displayPath(session.getCwd());
    ctx.ui.setFooter((tui, theme, footer) => {
      let leaf: string | null | undefined;
      let summary: ReturnType<typeof summarize> | undefined;
      let contextModel: typeof ctx.model;
      let usage: ReturnType<typeof ctx.getContextUsage>;
      return {
        dispose: footer.onBranchChange(() => tui.requestRender()),
        invalidate() {},
        render(width) {
          const model = ctx.model;
          const currentLeaf = session.getLeafId();
          const historyChanged = !summary || leaf !== currentLeaf;
          if (historyChanged || contextModel !== model) {
            contextModel = model;
            usage = ctx.getContextUsage();
          }
          if (!summary || historyChanged) {
            leaf = currentLeaf;
            summary = summarize(session.getEntries());
          }
          const percent = usage?.percent ?? 0;
          const contextSize = usage?.contextWindow ?? model?.contextWindow ?? 0;
          const context = `${usage?.percent === null ? "?" : percent.toFixed(1) + "%"}/${tokens(contextSize)}`;
          const contextColor = percent > 90 ? "error" : percent > 70 ? "warning" : "dim";
          let stats = "";
          let sessionId = "";
          let right = "";
          const leftText = () => join(stats, sessionId);
          const room = (left = leftText(), modelText = right) =>
            width - visibleWidth(left) - visibleWidth(modelText) - (left && modelText ? 2 : 0);
          function append(text: string): boolean {
            const next = join(stats, text);
            if (room(join(next, sessionId)) < 0) return false;
            stats = next;
            return true;
          }

          append(theme.fg(contextColor, context));
          if (id && room(join(stats, id)) >= 0) sessionId = theme.fg("dim", id);
          const latest = rate(summary.latest);
          const lifetime = rate(summary.lifetime);
          const cache = [latest, lifetime && `Σ${lifetime}`].filter(Boolean).join("/");
          if (cache && !append(theme.fg("dim", `CH${cache}`)) && latest) {
            append(theme.fg("dim", `CH${latest}`));
          }

          const modelId = model?.id ?? "no-model";
          const level = ctx.thinkingLevel ?? "off";
          const modelWithLevel = model?.reasoning ? join(modelId, level === "off" ? "thinking off" : level) : modelId;
          const modelRoom = room() - (leftText() ? 2 : 0);
          const qualified = model && footer.getAvailableProviderCount() > 1 ? `(${model.provider}) ${modelWithLevel}` : "";
          right = [qualified, modelWithLevel, modelId].find(text => text && visibleWidth(text) <= modelRoom) ?? fit(modelId, modelRoom);

          const subscription = model && (model.provider === "kimi-coding" ||
            (ctx.modelRegistry.isUsingOAuth(model) && ctx.modelRegistry.getProvider(model.provider)?.auth?.oauth?.isSubscription));
          if (summary.cost || subscription) append(theme.fg("dim", `$${summary.cost.toFixed(3)}${subscription ? " (sub)" : ""}`));

          const branch = footer.getGitBranch();
          let left = leftText();
          for (const text of [session.getSessionName() ?? "", cwd + (branch ? ` (${branch})` : "")]) {
            const prefix = fit(clean(text), room(left) - (left ? visibleWidth(dot) : right ? 2 : 0));
            if (prefix) left = join(theme.fg("dim", prefix), left);
          }
          const padding = right ? " ".repeat(width - visibleWidth(left) - visibleWidth(right)) : "";
          const lines = [left + padding + (right ? theme.fg("dim", right) : "")];
          const statuses = join(...[...footer.getExtensionStatuses()]
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([, text]) => clean(text).trim()));
          if (statuses) lines.push(truncateToWidth(statuses, width, "…"));
          return lines;
        },
      };
    });
  });
}
