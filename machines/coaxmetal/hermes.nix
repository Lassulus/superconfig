{
  self,
  config,
  pkgs,
  ...
}:
{
  imports = [
    self.inputs.hermes-agent.nixosModules.default
  ];

  # Hermes Agent (Nous Research) — autonomous agent run as a native systemd
  # gateway, reachable over Matrix (@hermes:lassul.us). Model backend is Nous
  # Portal (one key, 266 models) driving MiniMax M2.5 — an agentic model, per
  # Nous's own guidance that the Hermes-4 chat models are NOT for the agent.
  # Any Portal model is a one-line settings.model.default swap.
  services.hermes-agent = {
    enable = true;

    # Build the Matrix platform dependency group into the sealed venv (mautrix
    # SDK + liboqs for optional E2EE; Linux-only).
    extraDependencyGroups = [ "matrix" ];

    # Put the Claude Code CLI on the agent's PATH so its bundled "claude-code"
    # skill can delegate coding via `terminal(command="claude -p '...'")`.
    # extraPackages lands in both the systemd service PATH and the hermes
    # user's profile. Auth is separate (run `claude` once as the hermes user).
    extraPackages = [
      self.legacyPackages.${pkgs.system}.llm.claude-code
    ];

    settings.model = {
      # Nous does NOT recommend the Hermes-4 chat models for Hermes Agent — it
      # wants a dedicated *agentic* model. Community/Nous consensus agentic pick
      # is the MiniMax M2 family (Nous co-optimizes it for Hermes Agent); M2.5
      # is the cheapest tool-calling option ($0.12/$0.48 per 1M). All 266 Nous
      # Portal models share this key, so this is just a model-id swap.
      # Alternatives: minimax/minimax-m2.7, z-ai/glm-4.6, deepseek/deepseek-v3.2.
      default = "minimax/minimax-m2.5";
      # hermes's built-in "nous" provider is OAuth-only and hardcodes the dead
      # host inference.nousresearch.com (NXDOMAIN) — true on both 0.17.0 and
      # main; "nous-api" exists only in docs, not code. So we drive Nous Portal
      # through the generic OpenAI-compatible "custom" provider pointed at the
      # live endpoint, authenticating with the Nous key as OPENAI_API_KEY.
      provider = "custom";
      base_url = "https://inference-api.nousresearch.com/v1";
      # The custom provider can't auto-detect limits, so it left context
      # uncompressed and defaulted max_tokens to 65536 — once history passed
      # ~65k tokens, input + max_tokens exceeded the 131072 window and the
      # endpoint 400'd ("check the model name and other parameters"). Pin both:
      # context_length so hermes compresses before the window fills, and a sane
      # output cap (covers thinking + reply) so input + max_tokens stays under.
      context_length = 204800;
      max_tokens = 16384;

      # Frontier-on-tap alternative (uncomment to default to Claude instead):
      # default = "anthropic/claude-sonnet-4-6";
    };

    # In rooms Hermes requires an @mention by default; DMs always respond.
    settings.matrix.session_scope = "room";

    # Non-secret connection + SECURITY gate. Invites are auto-accepted and that
    # cannot be disabled, so the agent may join any room it's invited to. Joining
    # is harmless on its own — what matters is who can *trigger* the agent, which
    # on this host has terminal / filesystem / web tools (chat-driven RCE).
    # MATRIX_ALLOWED_USERS is the universal trigger gate (applies even in DMs);
    # only these MXIDs can make the agent act, in any room it's joined.
    environment = {
      MATRIX_HOMESERVER = "https://matrix.lassul.us";
      MATRIX_USER_ID = "@hermes:lassul.us";
      MATRIX_ALLOWED_USERS = "@lassulus:lassul.us";
      # Element makes DMs end-to-end encrypted by default, so the bot must do
      # E2EE or it can't read messages. The `matrix` dep group already bundles
      # mautrix[encryption] (python-olm); "optional" initializes E2EE when those
      # deps are present (they are) and keeps the crypto store under
      # /var/lib/hermes/.hermes/platforms/matrix/store/.
      MATRIX_E2EE_MODE = "optional";
      # Optional defense-in-depth (confine to specific rooms; DMs are exempt):
      # MATRIX_ALLOWED_ROOMS = "!yourRoomId:lassul.us";
    };

    # Secrets (MATRIX_ACCESS_TOKEN + NOUS_API_KEY) come from clan vars below,
    # merged into $HERMES_HOME/.env at activation.
    environmentFiles = [
      config.clan.core.vars.generators.hermes-env.files."hermes.env".path
    ];
  };

  # Boot-race guard. matrix.lassul.us is IPv6-only; on this desktop
  # network-online.target can fire before v6 DNS is ready, so the gateway's
  # first Matrix connect fails ("Name or service not known") and it does not
  # retry — leaving the bot silent until a manual restart. Block startup until
  # the homeserver resolves (best-effort, ~60s cap) so reboots come up
  # connected.
  systemd.services.hermes-agent.serviceConfig.ExecStartPre = [
    "${pkgs.writeShellScript "hermes-wait-matrix-dns" ''
      i=0
      while [ "$i" -lt 30 ]; do
        ${pkgs.getent}/bin/getent ahosts matrix.lassul.us >/dev/null 2>&1 && exit 0
        ${pkgs.coreutils}/bin/sleep 2
        i=$((i + 1))
      done
      echo "matrix.lassul.us did not resolve within 60s; starting anyway" >&2
      exit 0
    ''}"
  ];

  # Matrix bot access token for @hermes:lassul.us (minted against the neoprism
  # Synapse). persist=true so the prompt value is stored once.
  clan.core.vars.generators.hermes-matrix.prompts.matrix-access-token = {
    description = "Matrix access token for @hermes:lassul.us";
    type = "hidden";
    persist = true;
  };

  # Nous Portal API key (portal.nousresearch.com, Plus subscription).
  clan.core.vars.generators.hermes-nous.prompts.nous-api-key = {
    description = "Nous Portal API key (NOUS_API_KEY) from portal.nousresearch.com";
    type = "hidden";
    persist = true;
  };

  # Assemble the .env Hermes reads (mirrors the opencrow-env pattern).
  clan.core.vars.generators.hermes-env = {
    dependencies = [
      "hermes-matrix"
      "hermes-nous"
    ];
    files."hermes.env" = { };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      key=$(cat "$in"/hermes-nous/nous-api-key)
      cat > "$out/hermes.env" <<EOF
      MATRIX_ACCESS_TOKEN=$(cat "$in"/hermes-matrix/matrix-access-token)
      NOUS_API_KEY=$key
      OPENAI_API_KEY=$key
      EOF
    '';
  };
}
