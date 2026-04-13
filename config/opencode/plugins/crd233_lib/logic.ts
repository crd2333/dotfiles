export function resolveAlias(name: string, aliases: Record<string, string>): string {
  return aliases[name] ?? name
}

export function findExact(
  name: string,
  haystack: string[],
  aliases: Record<string, string>,
): string | undefined {
  if (haystack.includes(name)) return name
  const resolved = resolveAlias(name, aliases)
  if (resolved !== name && haystack.includes(resolved)) return resolved
  return undefined
}

export function computeList(
  enabled: string[],
  disabled: string[],
  aliases: Record<string, string>,
): string {
  const lines: string[] = ["Enabled plugins:"]
  if (enabled.length === 0) lines.push("  (none)")
  else for (const plugin of enabled) lines.push(`  ✓  ${plugin}`)

  lines.push("", "Disabled plugins:")
  if (disabled.length === 0) lines.push("  (none)")
  else for (const plugin of disabled) lines.push(`  ✗  ${plugin}`)

  const entries = Object.entries(aliases)
  lines.push("", "Aliases:")
  if (entries.length === 0) lines.push("  (none)")
  else {
    for (const [alias, target] of entries) {
      const exists = enabled.includes(target) || disabled.includes(target)
      const warning = exists ? "" : "  ⚠ target not found"
      lines.push(`  ${alias}  →  ${target}${warning}`)
    }
  }

  lines.push("", "Changes take effect after restarting OpenCode.")
  return lines.join("\n")
}

export type DisableResult = {
  message: string
  newEnabled?: string[]
  newDisabled?: string[]
}

export function computeDisable(
  name: string,
  enabled: string[],
  disabled: string[],
  aliases: Record<string, string>,
): DisableResult {
  const match = findExact(name, enabled, aliases)
  if (!match) {
    const resolved = resolveAlias(name, aliases)
    const aliasNote = resolved !== name ? ` (alias → '${resolved}')` : ""
    return {
      message: `Plugin '${name}'${aliasNote} not found in enabled list.\nRun /crd233/list to see exact plugin names.`,
    }
  }

  return {
    message: `Disabled '${match}'. Restart OpenCode to apply.`,
    newEnabled: enabled.filter(plugin => plugin !== match),
    newDisabled: disabled.includes(match) ? disabled : [...disabled, match],
  }
}

export type EnableResult = {
  message: string
  newEnabled?: string[]
  newDisabled?: string[]
}

export function computeEnable(
  name: string,
  enabled: string[],
  disabled: string[],
  aliases: Record<string, string>,
): EnableResult {
  const inEnabled = findExact(name, enabled, aliases)
  if (inEnabled) {
    const stale = disabled.find(plugin => plugin === inEnabled)
    if (stale) {
      return {
        message: `'${name}' is already enabled. Cleaned up stale disabled entry '${stale}'.`,
        newDisabled: disabled.filter(plugin => plugin !== stale),
      }
    }
    return { message: `'${name}' is already enabled.` }
  }

  const match = findExact(name, disabled, aliases)
  if (!match) {
    const resolved = resolveAlias(name, aliases)
    const aliasNote = resolved !== name ? ` (alias → '${resolved}')` : ""
    return {
      message: `Plugin '${name}'${aliasNote} not found in disabled list.\nRun /crd233/list to see exact plugin names.`,
    }
  }

  return {
    message: `Enabled '${match}'. Restart OpenCode to apply.`,
    newEnabled: [...enabled, match],
    newDisabled: disabled.filter(plugin => plugin !== match),
  }
}

export type AliasResult = {
  message: string
  newAliases?: Record<string, string>
}

export function computeAlias(
  args: string[],
  aliases: Record<string, string>,
  enabled: string[],
  disabled: string[],
): AliasResult {
  if (args.length === 0) {
    return { message: "Usage: /crd233/alias <shorthand> <name>  or  /crd233/unalias <shorthand>" }
  }

  const [shorthand, ...nameParts] = args
  const target = nameParts.join(" ")
  if (!target) {
    return { message: "Usage: /crd233/alias <shorthand> <plugin-name>" }
  }

  const allPlugins = [...enabled, ...disabled]
  if (!allPlugins.includes(target)) {
    return { message: `Plugin '${target}' not found.\nRun /crd233/list to see exact plugin names.` }
  }

  return {
    message: `Alias '${shorthand}' → '${target}' saved.`,
    newAliases: { ...aliases, [shorthand]: target },
  }
}

export type UnaliasResult = {
  message: string
  newAliases?: Record<string, string>
}

export function computeUnalias(
  shorthand: string | undefined,
  aliases: Record<string, string>,
): UnaliasResult {
  if (!shorthand) {
    return { message: "Error: /crd233/unalias requires a shorthand name." }
  }
  if (!(shorthand in aliases)) {
    return { message: `Alias '${shorthand}' not found.` }
  }
  const { [shorthand]: _removed, ...rest } = aliases
  return { message: `Removed alias '${shorthand}'.`, newAliases: rest }
}

export function help(): string {
  return [
    "Usage:",
    "  /crd233/list                     — show enabled / disabled plugins + aliases",
    "  /crd233/enable <name>            — enable a disabled plugin",
    "  /crd233/disable <name>           — disable an enabled plugin",
    "  /crd233/alias <shorthand> <name> — create or update an alias",
    "  /crd233/unalias <shorthand>      — remove an alias",
    "  /crd233/trellis_fix              — apply model settings to Trellis agents",
    "  /crd233/help                     — show this message",
    "",
    "Names must be exact. Use /crd233/list to inspect them.",
    "Aliases can be used anywhere a plugin name is accepted.",
  ].join("\n")
}
