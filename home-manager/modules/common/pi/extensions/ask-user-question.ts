/**
 * Ask User Question Extension
 *
 * Registers a tool that lets the LLM ask the user interactive questions
 * with optional multiple-choice selections. This enables the agent to
 * gather clarification, preferences, or decisions mid-turn without
 * interrupting the flow.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent"
import { Type } from "@sinclair/typebox"

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user_question",
    label: "Ask User Question",
    description: "Ask the user a question with optional choices. Use for clarification, preferences, or decisions.",
    parameters: Type.Object({
      question: Type.String({ description: "Question shown to the user" }),
      options: Type.Optional(Type.Array(Type.String(), { description: "Selectable options (omit for free-text input)" })),
      allowCustom: Type.Optional(Type.Boolean({ default: true, description: "When options are provided, allow a custom free-text answer too" })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      if (!ctx.hasUI) {
        return {
          isError: true,
          content: [{ type: "text", text: "UI is unavailable in this mode." }],
          details: {},
        }
      }

      const options = params.options ?? []
      const allowCustom = params.allowCustom ?? true

      // Free-text input when no options provided
      if (options.length === 0) {
        const answer = await ctx.ui.input(params.question)
        if (!answer) {
          return {
            content: [{ type: "text", text: "User cancelled." }],
            details: { answer: null },
          }
        }

        return {
          content: [{ type: "text", text: "User answered: " + answer }],
          details: { answer, mode: "input" },
        }
      }

      // Selection from options
      const customLabel = "Other (type custom answer)"
      const selectable = allowCustom ? [...options, customLabel] : options
      const selected = await ctx.ui.select(params.question, selectable)

      if (!selected) {
        return {
          content: [{ type: "text", text: "User cancelled." }],
          details: { answer: null },
        }
      }

      if (selected === customLabel) {
        const custom = await ctx.ui.input("Your answer")
        if (!custom) {
          return {
            content: [{ type: "text", text: "User cancelled." }],
            details: { answer: null },
          }
        }

        return {
          content: [{ type: "text", text: "User answered: " + custom }],
          details: { answer: custom, mode: "custom" },
        }
      }

      return {
        content: [{ type: "text", text: "User selected: " + selected }],
        details: { answer: selected, mode: "select" },
      }
    },
  })
}
