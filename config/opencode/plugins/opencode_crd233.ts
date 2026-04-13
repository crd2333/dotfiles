import type { Plugin } from "@opencode-ai/plugin"
import { readJsonArrayFile, readJsonObjectFile, resolveWritableConfig, writeConfigTarget, writeJsonFile } from "./crd233_lib/config"
import { computeAlias, computeDisable, computeEnable, computeList, computeUnalias, help } from "./crd233_lib/logic"
import { applyTrellisModels } from "./crd233_lib/trellis"
import { homedir } from "os"
import { join } from "path"

const DISABLED_PATH = join(homedir(), ".config", "opencode", "plugins-disabled.json")
const ALIASES_PATH = join(homedir(), ".config", "opencode", "plugins-aliases.json")

function readDisabled(): string[] {
  return readJsonArrayFile(DISABLED_PATH)
}

function writeDisabled(list: string[]): void {
  writeJsonFile(DISABLED_PATH, list)
}

function readAliases(): Record<string, string> {
  return readJsonObjectFile<Record<string, string>>(ALIASES_PATH)
}

function writeAliases(aliases: Record<string, string>): void {
  writeJsonFile(ALIASES_PATH, aliases)
}

function getPlugins(directory: string): { target: ReturnType<typeof resolveWritableConfig>; plugins: string[] } {
  const target = resolveWritableConfig(directory)
  const plugins = Array.isArray(target.config.plugin) ? target.config.plugin : []
  return { target, plugins }
}

async function resolveSessionDirectory(client: any, sessionID: string, fallbackDirectory: string): Promise<string> {
  try {
    const response = await client.session.get({ sessionID })
    const directory = response?.data?.directory
    if (typeof directory === "string" && directory.length > 0) {
      return directory
    }
  } catch {
    // ignore, use fallback
  }
  return fallbackDirectory
}

async function reply(client: any, sessionID: string, text: string): Promise<void> {
  await client.session.prompt({
    path: { id: sessionID },
    body: {
      noReply: true,
      parts: [{ type: "text", text }],
    },
  })
}

export const Crd233Plugin: Plugin = async ({ client, directory }) => {
  return {
    config: async input => {
      if (!input.command) input.command = {}
      Object.assign(input.command, {
        "crd233/help": {
          description: "Show crd233 plugin help",
          template: "Run /crd233/help",
        },
        "crd233/list": {
          description: "List enabled/disabled plugins and aliases",
          template: "Run /crd233/list",
        },
        "crd233/enable": {
          description: "Enable a plugin by exact name or alias",
          template: "Run /crd233/enable $ARGUMENTS",
        },
        "crd233/disable": {
          description: "Disable a plugin by exact name or alias",
          template: "Run /crd233/disable $ARGUMENTS",
        },
        "crd233/alias": {
          description: "Create or update a plugin alias",
          template: "Run /crd233/alias $ARGUMENTS",
        },
        "crd233/unalias": {
          description: "Remove a plugin alias",
          template: "Run /crd233/unalias $ARGUMENTS",
        },
        "crd233/trellis_fix": {
          description: "Apply model settings from ~/.config/opencode/trellis.json(c) to Trellis agents in the current project",
          template: "Run /crd233/trellis_fix",
        },
      })
    },

    "command.execute.before": async (input, output) => {
      if (!input.command?.startsWith("crd233/")) return

      const command = input.command
      const args = (input.arguments ?? "").trim().split(/\s+/).filter(Boolean)
      const sessionDirectory = await resolveSessionDirectory(client, input.sessionID, directory)

      try {
        let result: string

        switch (command) {
          case "crd233/list": {
            const { target, plugins } = getPlugins(sessionDirectory)
            const disabled = readDisabled()
            const aliases = readAliases()
            result = computeList(plugins, disabled, aliases)
            break
          }

          case "crd233/disable": {
            const payload = args.join(" ")
            if (!payload) {
              result = "Error: /crd233/disable requires a plugin name."
              break
            }
            const { target, plugins } = getPlugins(sessionDirectory)
            const disabled = readDisabled()
            const aliases = readAliases()
            const next = computeDisable(payload, plugins, disabled, aliases)
            if (next.newEnabled !== undefined) {
              target.config.plugin = next.newEnabled
              writeConfigTarget(target)
            }
            if (next.newDisabled) writeDisabled(next.newDisabled)
            result = next.message
            break
          }

          case "crd233/enable": {
            const payload = args.join(" ")
            if (!payload) {
              result = "Error: /crd233/enable requires a plugin name."
              break
            }
            const { target, plugins } = getPlugins(sessionDirectory)
            const disabled = readDisabled()
            const aliases = readAliases()
            const next = computeEnable(payload, plugins, disabled, aliases)
            if (next.newEnabled !== undefined) {
              target.config.plugin = next.newEnabled
              writeConfigTarget(target)
            }
            if (next.newDisabled) writeDisabled(next.newDisabled)
            result = next.message
            break
          }

          case "crd233/alias": {
            const { plugins } = getPlugins(sessionDirectory)
            const disabled = readDisabled()
            const aliases = readAliases()
            const next = computeAlias(args, aliases, plugins, disabled)
            if (next.newAliases) writeAliases(next.newAliases)
            result = next.message
            break
          }

          case "crd233/unalias": {
            const aliases = readAliases()
            const next = computeUnalias(args[0], aliases)
            if (next.newAliases) writeAliases(next.newAliases)
            result = next.message
            break
          }

          case "crd233/trellis_fix":
            result = applyTrellisModels(sessionDirectory)
            break

          default:
            result = help()
        }

        await reply(client, input.sessionID, result)
        throw new Error("Command handled by opencode_crd233")
      } catch (error: any) {
        if (error?.message === "Command handled by opencode_crd233") throw error
        const message = error?.message || String(error)
        await reply(client, input.sessionID, `crd233 error: ${message}`)
        throw error
      }
    },
  }
}

export const server = Crd233Plugin
export default Crd233Plugin
