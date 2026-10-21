declare module 'claude-code' {
  interface PluginState {
    'token-saver': {
      /** The Claude Docs block cut from the MCP instructions, handed over on the first Docs call of each loop. */
      docsInstructions: string
      /** The loops (`main`, or a subagent's id) that have read docsInstructions since their last compaction. */
      docsDelivered: Record<string, true>
      /** The largest remaining-token figure seen in this session, the baseline for BUDGET_SHOW_BELOW. */
      tokenBudgetMax: number
      /** Chinese main-loop text blocks still needed to clear the drift note; DRIFT_HOLD after an English one, 0 when off. */
      langDriftHold: number
    }
  }
}
