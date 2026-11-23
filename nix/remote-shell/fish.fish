# Source this file from ~/.config/fish/config.fish on the Drift host:
# test -f /software/drift/nix/remote-shell/fish.fish; and source /software/drift/nix/remote-shell/fish.fish
set -l drift_checkout (path resolve (status dirname)/../..)

# Interactive SSH sessions enter the development environment and remain in
# Fish. IN_NIX_SHELL prevents the inner Fish process from re-entering Nix.
if status is-interactive; and isatty stdout; and set -q SSH_CONNECTION; and not set -q IN_NIX_SHELL
    if test -f "$drift_checkout/flake.nix"; and command -q nix
        cd "$drift_checkout"
        nix develop . -c fish
    end
end

# Fish 4 does not expose the command passed to `fish -c` in $argv while this
# file is sourced, so recover it from argv[3] in /proc/self/cmdline.
if not status is-interactive; and set -q SSH_CONNECTION; and not set -q IN_NIX_SHELL
    set -l cmd (string split0 </proc/self/cmdline)[3]
    if set -q cmd[1]; and string match -q -- '*zed*' $cmd
        if command -q nix; and test -f "$drift_checkout/flake.nix"; and nix flake metadata "$drift_checkout" >/dev/null 2>&1
            exec env DRIFT_QUIET=1 nix develop "$drift_checkout" -c bash -c $cmd
        else
            exec /bin/sh -c $cmd
        end
    end
end
