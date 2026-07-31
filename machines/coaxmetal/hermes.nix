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
  # gateway, reachable over Matrix (@hermes:lassul.us). Model backend is our
  # shared llama cluster: one vLLM instance behind an OpenAI-compatible
  # endpoint, so the model is whatever the cluster currently serves and a swap
  # is a one-line settings.model.default change.
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
      # The cluster serves Qwen3.6-27B-FP8 (also aliased as "default" in
      # /v1/models — both resolve to the same weights); pin the explicit id so
      # logs and 400s name the actual model. Verified against the live endpoint
      # that it emits native tool_calls, which Hermes Agent requires.
      default = "Qwen3.6-27B-FP8";
      # hermes's built-in "nous" provider is OAuth-only and hardcodes the dead
      # host inference.nousresearch.com (NXDOMAIN) — true on both 0.17.0 and
      # main, so we drive the cluster's OpenAI-compatible endpoint instead.
      #
      # It MUST be a *named* custom provider ("custom:<name>" + a
      # custom_providers entry), not bare "custom". Bare custom resolves its
      # credential from a host-gated candidate list
      # (hermes_cli/runtime_provider.py:1244) that only forwards
      # OPENAI_API_KEY when base_url's host is openai.com — a deliberate
      # anti-credential-leak measure (upstream #28660 / GHSA-76xc-57q6-vm5m).
      # For any other host it silently substitutes the literal placeholder
      # "no-key-required" and the endpoint 401s. A named entry instead reads
      # the key from its declared key_env (runtime_provider.py:692), which is
      # not host-gated. Named entries also ignore config.yaml's model.api_key,
      # so a stray `hermes model` run can no longer shadow this with a stale
      # key (that is exactly how the Nous→cluster switch broke).
      provider = "custom:llama";
      base_url = "https://inference.p0.contact/v1";
      # The custom provider can't auto-detect limits, so unset it leaves
      # context uncompressed and defaults max_tokens to 65536 — once history
      # outgrows the window, input + max_tokens exceeds it and the endpoint
      # 400s ("check the model name and other parameters"). vLLM reports
      # max_model_len 262144 for this model: pin that as the window so hermes
      # compresses in time, and keep a sane output cap (covers thinking +
      # reply) so input + max_tokens always stays under it.
      context_length = 262144;
      max_tokens = 16384;
    };

    # The endpoint hermes actually authenticates against. key_env names the
    # env var carrying the token; it comes from the hermes-env generator below
    # via environmentFiles, so the secret never enters the nix store.
    # api_mode is pinned because auto-detection only runs as a fallback.
    settings.custom_providers = [
      {
        name = "llama";
        base_url = "https://inference.p0.contact/v1";
        key_env = "LLAMA_API_TOKEN";
        api_mode = "chat_completions";
      }
    ];

    # In rooms Hermes requires an @mention by default; DMs always respond.
    settings.matrix.session_scope = "room";

    # Matrix is a Tier-2 platform whose default tool-progress preview caps
    # commands at 40 chars (so a `terminal` call shows only `curl -X POST -H
    # "Content-Type: applic...`). "verbose" makes the gateway render the FULL
    # command — multi-line — as a fenced code block instead of the truncated
    # one-liner. Trade-off: verbose also prints full JSON args for every other
    # tool call, so the channel is chattier.
    settings.display.platforms.matrix.tool_progress = "verbose";

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

    # Secrets (MATRIX_ACCESS_TOKEN + LLAMA_API_TOKEN) come from clan vars below,
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

  # API token for the shared llama cluster, surfaced to hermes as
  # LLAMA_API_TOKEN (the custom_providers key_env above).
  # persist=true so the prompt value is stored once.
  clan.core.vars.generators.hermes-llama.prompts.llama-api-token = {
    description = "API token for the shared llama cluster (inference.p0.contact)";
    type = "hidden";
    persist = true;
  };

  # Assemble the .env Hermes reads (mirrors the opencrow-env pattern).
  clan.core.vars.generators.hermes-env = {
    dependencies = [
      "hermes-matrix"
      "hermes-llama"
    ];
    files."hermes.env" = { };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      cat > "$out/hermes.env" <<EOF
      MATRIX_ACCESS_TOKEN=$(cat "$in"/hermes-matrix/matrix-access-token)
      LLAMA_API_TOKEN=$(cat "$in"/hermes-llama/llama-api-token)
      EOF
    '';
  };
}
