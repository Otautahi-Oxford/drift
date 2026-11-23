# Source this file from ~/.zshenv on the Drift host:
# [[ -f /software/drift/nix/remote-shell/zsh.zsh ]] && source /software/drift/nix/remote-shell/zsh.zsh
# Resolve this sourced file, then walk up from nix/remote-shell to the checkout.
drift_checkout=${${(%):-%x}:A:h:h:h}

# Interactive SSH sessions enter the development environment and remain in
# Zsh. IN_NIX_SHELL prevents the inner Zsh process from re-entering Nix.
if [[ -o interactive && -t 1 && -n "$SSH_CONNECTION" && -z "$IN_NIX_SHELL" ]]; then
    if [[ -f "$drift_checkout/flake.nix" ]] && command -v nix >/dev/null 2>&1; then
        cd "$drift_checkout"
        nix develop . -c zsh
    fi
fi

# Non-interactive remote commands expose the original `zsh -c` string here.
# Only the Zed startup command is handed to the development environment.
if [[ ! -o interactive && -n "$SSH_CONNECTION" && -z "$IN_NIX_SHELL" \
      && -n "$ZSH_EXECUTION_STRING" && "$ZSH_EXECUTION_STRING" == *zed* ]]; then
    if command -v nix >/dev/null 2>&1 && [[ -f "$drift_checkout/flake.nix" ]] \
       && nix flake metadata "$drift_checkout" >/dev/null 2>&1; then
        exec env DRIFT_QUIET=1 nix develop "$drift_checkout" -c bash -c "$ZSH_EXECUTION_STRING"
    else
        exec /bin/sh -c "$ZSH_EXECUTION_STRING"
    fi
fi
unset drift_checkout
