{
  description = "AtCoder C++ workspace";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              gcc
              gdb
              clang-tools
              gnumake
              ac-library
              python3
              python3Packages.online-judge-tools
              jq
            ];

            shellHook = ''
              # Resolve root relative to this flake so commands also work when
              # entering the shell from outside the repository directory.
              export ATCODER_ROOT="${toString ./.}"
              if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
                export ATCODER_ROOT="$git_root"
              fi
              export CXX=${pkgs.gcc}/bin/g++
              export ATCODER_ACL_INCLUDE="${pkgs.ac-library}/include"
              export CPLUS_INCLUDE_PATH="$ATCODER_ACL_INCLUDE''${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
              export CPATH="$ATCODER_ACL_INCLUDE''${CPATH:+:$CPATH}"
              export CXXFLAGS="-std=gnu++20 -O2 -I$ATCODER_ACL_INCLUDE -Wall -Wextra -Wshadow -Wconversion -Wno-sign-conversion"
              export CXXFLAGS_DEBUG="-std=gnu++20 -g -O0 -I$ATCODER_ACL_INCLUDE -Wall -Wextra -Wshadow -Wconversion -Wno-sign-conversion"
              export CONTEST_MODE=1
              export NVIM_APPNAME=nvim-atcoder
              export ATCODER_TEMPLATE="$ATCODER_ROOT/template/main.cpp"
              export PATH="$ATCODER_ROOT/bin:$PATH"

              # Disable AI integrations explicitly in contest shell.
              unset OPENAI_API_KEY ANTHROPIC_API_KEY GOOGLE_API_KEY

              mkdir -p "$HOME/.config/nvim-atcoder"
              # Install the contest-mode nvim config from the repo. It is kept
              # as a real .lua file (config/nvim-atcoder/init.lua) instead of an
              # embedded heredoc so it can be edited/linted normally.
              if [[ -f "$ATCODER_ROOT/config/nvim-atcoder/init.lua" ]]; then
                cp "$ATCODER_ROOT/config/nvim-atcoder/init.lua" \
                   "$HOME/.config/nvim-atcoder/init.lua"
              fi

              echo "[atcoder] contest shell loaded"
              echo "[atcoder] commands: ac test, ac build, ac new, ac submit"
              echo "[atcoder] nvim: base config (AI plugins not installed in dotfiles)"

              # Prefer zsh for interactive `nix develop` sessions.
              # Keep non-interactive `nix develop -c ...` behavior unchanged.
              # Run this at the end so PATH/setup above is preserved.
              # Note: we deliberately do NOT gate on a persistent bootstrap env
              # var: if a prior `nix develop` set it and exec zsh failed (or the
              # user is nested inside that broken shell), the var would leak and
              # block every subsequent launch. Re-exec is already prevented by the
              # ZSH_VERSION check below (zsh does not re-run the nix shellHook).
              if [[ -t 0 && -t 1 && -z "''${ZSH_VERSION:-}" ]]; then
                export SHELL=${pkgs.zsh}/bin/zsh
                # zsh completion: launch a login zsh whose ZDOTDIR is a tiny
                # wrapper that (1) prepends our completions dir to fpath before
                # the user's .zshrc (and its compinit) runs, and (2) still
                # sources ALL of the user's real startup files (.zshenv,
                # .zprofile, .zshrc, .zlogin) so nothing they configured is
                # skipped. Only the fpath array is touched (not the FPATH env
                # var) so zsh's default fpath (colors/promptinit/etc.) survives.
                # If the wrapper cannot be written, fall back to a plain login
                # zsh (no completion) so the shell still launches.
                _ac_zdotdir="/tmp/atcoder-ac-zdotdir-$$"
                if rm -rf "$_ac_zdotdir" 2>/dev/null \
                   && mkdir -p "$_ac_zdotdir" 2>/dev/null \
                   && printf '%s\n' '[ -n "$HOME" ] && [ -f "$HOME/.zshenv" ] && source "$HOME/.zshenv"' > "$_ac_zdotdir/.zshenv" 2>/dev/null \
                   && printf '%s\n' '[ -n "$HOME" ] && [ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"' > "$_ac_zdotdir/.zprofile" 2>/dev/null \
                   && printf '%s\n' 'fpath=("''${ATCODER_ROOT}/completions" $fpath)' '[ -n "$HOME" ] && [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"' > "$_ac_zdotdir/.zshrc" 2>/dev/null \
                   && printf '%s\n' '[ -n "$HOME" ] && [ -f "$HOME/.zlogin" ] && source "$HOME/.zlogin"' > "$_ac_zdotdir/.zlogin" 2>/dev/null; then
                  ZDOTDIR="$_ac_zdotdir" exec ${pkgs.zsh}/bin/zsh -l
                fi
                exec ${pkgs.zsh}/bin/zsh -l
              fi
            '';
          };
        }
      );
    };
}
