import { existsSync, readFileSync, writeFileSync } from "fs"
import { homedir } from "os"
import { join } from "path"

export type ConfigTarget = {
  path: string
  format: "json" | "jsonc"
  config: Record<string, any>
}

function stripJsonComments(input: string): string {
  let result = ""
  let inString = false
  let stringQuote = '"'
  let escaped = false
  let i = 0

  while (i < input.length) {
    const char = input[i]
    const next = input[i + 1]

    if (inString) {
      result += char
      if (escaped) {
        escaped = false
      } else if (char === "\\") {
        escaped = true
      } else if (char === stringQuote) {
        inString = false
      }
      i += 1
      continue
    }

    if ((char === '"' || char === "'")) {
      inString = true
      stringQuote = char
      result += char
      i += 1
      continue
    }

    if (char === "/" && next === "/") {
      i += 2
      while (i < input.length && input[i] !== "\n") i += 1
      continue
    }

    if (char === "/" && next === "*") {
      i += 2
      while (i + 1 < input.length && !(input[i] === "*" && input[i + 1] === "/")) i += 1
      i += 2
      continue
    }

    result += char
    i += 1
  }

  return result
}

function stripTrailingCommas(input: string): string {
  return input.replace(/,\s*([}\]])/g, "$1")
}

export function parseJsonc(input: string): any {
  return JSON.parse(stripTrailingCommas(stripJsonComments(input)))
}

function readMaybeJsonc(filePath: string): Record<string, any> {
  const raw = readFileSync(filePath, "utf-8")
  if (filePath.endsWith(".jsonc")) {
    return parseJsonc(raw)
  }
  try {
    return JSON.parse(raw)
  } catch {
    return parseJsonc(raw)
  }
}

export function getProjectConfigPaths(directory: string): string[] {
  return [join(directory, "opencode.jsonc"), join(directory, "opencode.json")]
}

export function getGlobalConfigPaths(): string[] {
  const root = join(homedir(), ".config", "opencode")
  return [join(root, "opencode.jsonc"), join(root, "opencode.json")]
}

export function resolveWritableConfig(directory: string): ConfigTarget {
  const candidates = [...getProjectConfigPaths(directory), ...getGlobalConfigPaths()]
  for (const path of candidates) {
    if (existsSync(path)) {
      return {
        path,
        format: path.endsWith(".jsonc") ? "jsonc" : "json",
        config: readMaybeJsonc(path),
      }
    }
  }

  const fallback = getProjectConfigPaths(directory)[0]
  return { path: fallback, format: "jsonc", config: {} }
}

export function writeConfigTarget(target: ConfigTarget): void {
  const serialized = `${JSON.stringify(target.config, null, 2)}\n`
  writeFileSync(target.path, serialized, "utf-8")
}

export function readJsonArrayFile(filePath: string): string[] {
  if (!existsSync(filePath)) return []
  try {
    const value = readMaybeJsonc(filePath)
    return Array.isArray(value) ? value : []
  } catch {
    return []
  }
}

export function writeJsonFile(filePath: string, value: any): void {
  writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf-8")
}

export function readJsonObjectFile<T extends Record<string, any>>(filePath: string): T {
  if (!existsSync(filePath)) return {} as T
  try {
    const value = readMaybeJsonc(filePath)
    return (value && typeof value === "object" && !Array.isArray(value) ? value : {}) as T
  } catch {
    return {} as T
  }
}
