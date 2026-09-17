{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Pinned Piper voice for the bot's spoken replies. Single-speaker on purpose:
  # the radio's libritts-high (2configs/services/radio/tts.nix) is multi-speaker
  # and needs an -s speaker id per call.
  piperVoice = pkgs.runCommand "piper-voice-en_US-lessac-medium" { } ''
    mkdir -p $out
    ln -s ${
      pkgs.fetchurl {
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx?download=true";
        hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
      }
    } $out/model.onnx
    ln -s ${
      pkgs.fetchurl {
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json?download=true";
        hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
      }
    } $out/model.onnx.json
  '';

  # TTS backend for the gateway, wired as a `type: command` provider below.
  #
  # Hermes's built-in `tts.provider = "piper"` cannot work on this deployment:
  # it imports the `piper` Python module, which is in neither the sealed uv2nix
  # venv nor tools/lazy_deps.py's install allowlist, and the venv is a
  # read-only store path — so its lazy `pip install` has nowhere to land. Same
  # for the upstream default "edge" (lazy edge-tts). A command provider calls
  # nixpkgs' piper instead: no runtime pip, no runtime voice download.
  #
  # Contract: hermes writes the reply text to $1 and expects audio at $2.
  hermes-tts = pkgs.writeShellApplication {
    name = "hermes-tts";
    runtimeInputs = [ pkgs.piper-tts ];
    text = ''
      piper --model ${piperVoice}/model.onnx --output-file "$2" < "$1"
    '';
  };

  # herdr keeps its API socket under the session owner's
  # $HOME/.config/herdr/herdr.sock (verified on this host: the running server
  # has HOME=/home/lass and listens on /home/lass/.config/herdr/herdr.sock),
  # and the herd runs as lass — so the hermes user cannot see any pane without
  # crossing the user boundary. sudo's env_reset leaves HOME pointing at the
  # *calling* user, which made the CLI look for a socket under
  # /var/lib/hermes/.config and report "no herdr server is running", so set it
  # here. Keeping the env setup inside a store script also means sudoers
  # matches one fixed path instead of an argv template.
  herdr-as-lass = pkgs.writeShellApplication {
    name = "herdr-as-lass";
    text = ''
      export HOME=${config.users.users.mainUser.home}
      exec ${self.inputs.llm-agents.packages.${pkgs.system}.herdr}/bin/herdr "$@"
    '';
  };

  # What the agent actually calls: `herdr agent list`, `herdr agent read <id>`,
  # `herdr agent prompt <id> '...'`. Named plainly because the gateway's PATH
  # is hermes + bash + coreutils + git + extraPackages — /run/current-system/sw
  # is absent, so there is no real `herdr` to shadow.
  herdr = pkgs.writeShellApplication {
    name = "herdr";
    text = ''
      exec /run/wrappers/bin/sudo -u ${config.users.users.mainUser.name} \
        ${herdr-as-lass}/bin/herdr-as-lass "$@"
    '';
  };
in
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
    # SDK + liboqs for optional E2EE; Linux-only). "voice" adds faster-whisper,
    # which is what `stt.provider = "local"` below runs — that group exists
    # precisely because local STT pulls wheel-only transitive deps
    # (ctranslate2, onnxruntime) that uv2nix has to resolve at build time.
    extraDependencyGroups = [
      "matrix"
      "voice"
    ];

    # Put the Claude Code CLI on the agent's PATH so its bundled "claude-code"
    # skill can delegate coding via `terminal(command="claude -p '...'")`.
    # extraPackages lands in both the systemd service PATH and the hermes
    # user's profile. Auth is separate (run `claude` once as the hermes user).
    extraPackages = [
      self.legacyPackages.${pkgs.system}.llm.claude-code
      # Voice both ways: the Matrix adapter shells out to ffmpeg to transcode
      # piper's WAV to Ogg/Opus (native MSC3245 voice bubbles in Element) and
      # to ffprobe for the duration + waveform metadata those bubbles carry.
      pkgs.ffmpeg
      hermes-tts
      # Drive the herd from a voice note: "read me what the agent on herdr is
      # stuck on" -> herdr agent list / read / prompt, as lass.
      herdr
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

    # Voice in. Element voice notes arrive flagged MSC3245; the Matrix adapter
    # recognizes that flag and routes the audio to STT before the agent sees
    # the turn, so a held-down mic button is just another prompt.
    #
    # "local" = faster-whisper in-process (from the "voice" dep group). An
    # explicit provider is honored strictly: if it cannot run, transcription
    # errors out loud instead of silently falling back to a cloud key.
    settings.stt = {
      provider = "local";
      # "" = auto-detect per clip, instead of upstream's "en" hint — commands
      # here switch between English and German mid-conversation.
      language = "";
      # Vocabulary bias (faster-whisper initial_prompt). Measured on this host:
      # "the agent on herdr is blocked" transcribes as "the agent on Herter"
      # without it and verbatim with it. Every name here is one the agent has
      # to route on — a misheard host or tool name is a failed command, not a
      # typo.
      prompt = "Jargon: herdr, omp, nix, clan, retiolum, coaxmetal, neoprism, ignavia, lassulus.";
      local = {
        # small is the first size whose transcripts survive our jargon; a 4s
        # clip takes ~3s warm on this CPU (int8), ~6s from cold weights.
        model = "small";
        # Release the weights after five idle minutes; this is a laptop, and
        # the next voice note pays the reload instead of holding the RAM.
        unload_after_idle_seconds = 300;
      };
    };

    # Voice out. `voice_compatible` is the opt-in that makes the gateway treat
    # this provider's output as a voice message (Opus-transcoding it on the
    # way) rather than a file attachment, so replies land as playable bubbles.
    settings.tts = {
      provider = "piper-local";
      providers.piper-local = {
        type = "command";
        command = "${hermes-tts}/bin/hermes-tts {input_path} {output_path}";
        output_format = "wav";
        voice_compatible = true;
      };
    };

    # Speak every gateway reply, not just ones requested with /voice tts. The
    # toggle also takes a lease on the engine, so the first spoken reply after
    # startup does not pay model load as silence. Turn it off per chat with
    # /voice off.
    settings.voice.auto_tts = true;

    # In rooms Hermes requires an @mention by default; DMs always respond.
    settings.matrix.session_scope = "room";

    # Matrix is a Tier-2 platform whose default tool-progress preview caps
    # commands at 40 chars (so a `terminal` call shows only `curl -X POST -H
    # "Content-Type: applic...`). "verbose" makes the gateway render the FULL
    # command — multi-line — as a fenced code block instead of the truncated
    # one-liner. Trade-off: verbose also prints full JSON args for every other
    # tool call, so the channel is chattier.
    settings.display.platforms.matrix.tool_progress = "verbose";

    # Teach the agent the herd. Without this the `herdr` wrapper is just an
    # unadvertised binary on PATH: nothing in the model's context would make it
    # reach for the herd when a voice note says "what is the agent stuck on".
    # Skills are loaded from $HERMES_HOME/skills/<name>/SKILL.md.
    hermesHomeFiles."skills/herdr/SKILL.md" = ''
      ---
      name: herdr
      description: Inspect and steer the coding agents running in lass's herdr session on this machine.
      version: 1.0.0
      license: MIT
      platforms: [linux]
      metadata:
        hermes:
          tags: [herdr, agents, terminal, coding, inspect]
      ---

      # herdr

      `herdr` on this host is a wrapper that talks to lass's running herdr
      server (the agent multiplexer holding the coding-agent panes). Every
      invocation prints JSON.

      Use it whenever the user asks about "the agents", "the herd", "the
      session on herdr", what something is "stuck on", or wants a prompt or
      answer delivered to a running agent.

      | Command | Use |
      | --- | --- |
      | `herdr agent list` | Every agent with its state: working, blocked, idle, done. Start here. |
      | `herdr agent get <agent>` | One agent's detail (workspace, tab, pane, cwd). |
      | `herdr agent read <agent>` | Recent terminal output. This is how you answer "what is it doing/asking". |
      | `herdr agent prompt <agent> '<text>'` | Submit a prompt to that agent, e.g. to unblock an approval. |
      | `herdr agent wait <agent> --state idle` | Block until it reaches a state. |
      | `herdr workspace list` / `herdr tab list` / `herdr pane list` | Structure, when agent-level views are not enough. |
      | `herdr --skill` | herdr's own, fuller usage reference — read it before improvising flags. |

      Answering by voice: the reply is spoken, so summarize what `agent read`
      shows in a sentence or two instead of reciting scrollback, and say the
      agent's name and state first. Read a diff or a stack trace aloud only if
      asked.

      Blocked agents are the interesting case: report what the agent is waiting
      for, and only run `herdr agent prompt` when the user actually decides.
      Never close panes or kill agents on your own.
    '';

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

      # The OpenAI-compatible API server: the assistant-button lane, reached
      # both directly from massulus.r and through the public
      # hermes.lassul.us proxy on neoprism. API_SERVER_KEY comes from clan
      # vars via environmentFiles; API_SERVER_HOST is written at start by the
      # ExecStartPre below (the retiolum address). Unlike Matrix there is no
      # per-user allowlist here — the bearer token is the whole gate.
      API_SERVER_ENABLED = "true";
      API_SERVER_PORT = "8642";
    };

    # Secrets (MATRIX_ACCESS_TOKEN + LLAMA_API_TOKEN) come from clan vars below,
    # merged into $HERMES_HOME/.env at activation.
    environmentFiles = [
      config.clan.core.vars.generators.hermes-env.files."hermes.env".path
    ];
  };

  # The herd/hermes user boundary. herdr keeps its API socket in the session
  # owner's runtime dir, so reaching lass's panes means running as lass.
  #
  # Be clear about what this grants: `herdr pane run` / `agent prompt` execute
  # commands inside lass's panes, so this is lass-level code execution for
  # anything that can drive the agent — it does not narrow the existing threat
  # model (the gateway already has terminal tools as hermes), but it widens the
  # blast radius from the hermes user to lass. The gate stays
  # MATRIX_ALLOWED_USERS above. Restricting the command to one store path only
  # buys auditability, not containment.
  security.sudo.extraRules = [
    {
      users = [ config.services.hermes-agent.user ];
      runAs = config.users.users.mainUser.name;
      commands = [
        {
          command = "${herdr-as-lass}/bin/herdr-as-lass";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
      ];
    }
  ];

  # sudo is setuid, and the upstream unit sets NoNewPrivileges=yes, which makes
  # every setuid exec fail — so the wrapper above returned "sudo: The "no new
  # privileges" flag is set, which prevents sudo from running as root" and the
  # agent reported the herd as unreachable. Turning it off for this unit is the
  # price of the bridge; it only re-enables what the sudoers rule already
  # allows (one store path, runas lass), since sudo itself is the only setuid
  # binary the agent is pointed at.
  # The module hardens the unit with NoNewPrivileges = true, hence mkForce.
  systemd.services.hermes-agent.serviceConfig.NoNewPrivileges = lib.mkForce false;

  # Boot-race guard. matrix.lassul.us is IPv6-only; on this desktop
  # network-online.target can fire before v6 DNS is ready, so the gateway's
  # first Matrix connect fails ("Name or service not known") and it does not
  # retry — leaving the bot silent until a manual restart. Block startup until
  # the homeserver resolves (best-effort, ~60s cap) so reboots come up
  # connected.
  #
  # The second entry resolves the API server's bind address (see the
  # API_SERVER_* environment above). Retiolum, because both consumers live
  # there: massulus.r talks to it directly, and neoprism reverse-proxies it
  # to hermes.lassul.us. This host joins untrusted networks, so binding the
  # mesh address rather than "::" keeps the listener off café wifi even
  # before the packet filter sees it; the public door is nginx on neoprism,
  # which we control.
  #
  # It is resolved at start rather than hardcoded because the address derives
  # from the retiolum key in clan vars, so a regenerated key would otherwise
  # leave the unit bound to a stale literal. It waits because the interface
  # gets its address after network-online, and aiohttp cannot bind an address
  # that does not exist yet. "+" runs it as root: /run is not writable by
  # hermes.
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
    "+${pkgs.writeShellScript "hermes-api-bind-retiolum" ''
      set -eu
      i=0
      while [ "$i" -lt 30 ]; do
        addr=$(${pkgs.iproute2}/bin/ip -6 -o addr show dev retiolum scope global \
          | ${pkgs.gawk}/bin/awk '{print $4}' | ${pkgs.coreutils}/bin/cut -d/ -f1 \
          | ${pkgs.coreutils}/bin/head -n1)
        if [ -n "$addr" ]; then
          ${pkgs.coreutils}/bin/mkdir -p /run/hermes-api
          echo "API_SERVER_HOST=$addr" > /run/hermes-api/host.env
          ${pkgs.coreutils}/bin/chmod 0444 /run/hermes-api/host.env
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 2
        i=$((i + 1))
      done
      # No retiolum address: leave the file absent so the API server falls
      # back to its 127.0.0.1 default rather than silently listening on every
      # interface. The Matrix lane keeps working either way.
      ${pkgs.coreutils}/bin/rm -f /run/hermes-api/host.env
      echo "retiolum has no global address after 60s; API server stays on localhost" >&2
      exit 0
    ''}"
  ];

  # The packet filter drops INPUT by default here (2configs/default.nix sets
  # filter.INPUT.policy = "DROP"), so the API server's port has to be opened
  # for the interface it binds. Without this neoprism's proxy_pass times out
  # and hermes.lassul.us answers 504, while a local curl to the same
  # address:port returns 200 — traffic to the host's own address goes through
  # lo, which is accepted.
  networking.firewall.interfaces.retiolum.allowedTCPPorts = [ 8642 ];

  # "-" because the file is absent until the ExecStartPre above finds an
  # address, and a missing bind override must not fail the unit.
  systemd.services.hermes-agent.serviceConfig.EnvironmentFile = [
    "-/run/hermes-api/host.env"
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

  # Bearer token for the API server. Generated, not prompted, and kept in a
  # separate file as well so it can be read back out for the phone:
  #   clan vars get coaxmetal hermes-api/api_key
  # (same shape as the covibe api_key generator).
  clan.core.vars.generators.hermes-api = {
    files."api_key" = { };
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
    ];
    script = ''
      openssl rand -hex 32 | tr -d '\n' > "$out/api_key"
    '';
  };

  # Assemble the .env Hermes reads (mirrors the opencrow-env pattern).
  clan.core.vars.generators.hermes-env = {
    dependencies = [
      "hermes-matrix"
      "hermes-llama"
      "hermes-api"
    ];
    files."hermes.env" = { };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      cat > "$out/hermes.env" <<EOF
      MATRIX_ACCESS_TOKEN=$(cat "$in"/hermes-matrix/matrix-access-token)
      LLAMA_API_TOKEN=$(cat "$in"/hermes-llama/llama-api-token)
      API_SERVER_KEY=$(cat "$in"/hermes-api/api_key)
      EOF
    '';
  };
}
