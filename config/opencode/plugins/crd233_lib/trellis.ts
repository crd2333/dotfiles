import { existsSync, readFileSync, writeFileSync } from "fs"
import { homedir } from "os"
import { join } from "path"
import { parseJsonc } from "./config"

export type TrellisModelEntry = {
  model: string
  temperature?: number
}

export type TrellisModelsConfig = {
  agents?: Record<string, string | TrellisModelEntry>
}

const AGENT_FILES = ["trellis-plan", "dispatch", "research", "implement", "check", "debug"]

function readTrellisConfig(): TrellisModelsConfig | null {
  const base = join(homedir(), ".config", "opencode")
  const candidates = [join(base, "trellis.jsonc"), join(base, "trellis.json")]
  for (const path of candidates) {
    if (!existsSync(path)) continue
    const raw = readFileSync(path, "utf-8")
    try {
      return path.endsWith(".jsonc") ? parseJsonc(raw) : JSON.parse(raw)
    } catch {
      try {
        return parseJsonc(raw)
      } catch {
        return null
      }
    }
  }
  return null
}

function upsertFrontmatter(content: string, key: string, value: string | number): string {
  const lines = content.split("\n")
  if (lines[0] !== "---") return content
  let end = -1
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") {
      end = i
      break
    }
  }
  if (end === -1) return content

  const keyPrefix = `${key}:`
  for (let i = 1; i < end; i++) {
    if (lines[i].startsWith(keyPrefix)) {
      lines[i] = `${key}: ${JSON.stringify(value)}`
      return lines.join("\n")
    }
  }

  lines.splice(end, 0, `${key}: ${JSON.stringify(value)}`)
  return lines.join("\n")
}

export function applyTrellisModels(directory: string): string {
  const trellisDir = join(directory, ".trellis")
  if (!existsSync(trellisDir)) {
    return "No Trellis project detected. Nothing changed."
  }

  const config = readTrellisConfig()
  if (!config?.agents || Object.keys(config.agents).length === 0) {
    return "Trellis detected, but ~/.config/opencode/trellis.json(c) has no agent model mappings."
  }

  const agentsDir = join(directory, ".opencode", "agents")
  if (!existsSync(agentsDir)) {
    return "Trellis detected, but .opencode/agents is missing. Nothing changed."
  }

  const updated: string[] = []
  const skipped: string[] = []

  for (const agentName of AGENT_FILES) {
    const mapping = config.agents[agentName]
    if (!mapping) {
      skipped.push(agentName)
      continue
    }

    const agentPath = join(agentsDir, `${agentName}.md`)
    if (!existsSync(agentPath)) {
      skipped.push(agentName)
      continue
    }

    const raw = readFileSync(agentPath, "utf-8")
    const entry = typeof mapping === "string" ? { model: mapping } : mapping
    let next = upsertFrontmatter(raw, "model", entry.model)
    if (typeof entry.temperature === "number") {
      next = upsertFrontmatter(next, "temperature", entry.temperature)
    }
    if (next !== raw) {
      writeFileSync(agentPath, next, "utf-8")
      updated.push(agentName)
    }
  }

  const lines = ["Applied Trellis model settings."]
  lines.push(updated.length ? `Updated: ${updated.join(", ")}` : "Updated: (none)")
  if (skipped.length) lines.push(`Skipped: ${skipped.join(", ")}`)
  return lines.join("\n")
}
