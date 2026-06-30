# bash completion for the `ac` dispatcher. Source this from .bashrc:
#   source "$ATCODER_ROOT/completions/ac.bash"

_ac() {
  local cur sub
  cur="${COMP_WORDS[COMP_CWORD]}"
  sub="${COMP_WORDS[1]:-}"

  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "test build new submit submit-direct cookie-import --help -h" -- "$cur") )
    return
  fi

  case "$sub" in
    test|build)
      COMPREPLY=( $(compgen -W "--debug --release --build-only --full --help -h" -- "$cur") )
      ;;
    submit|submit-direct)
      COMPREPLY=( $(compgen -W "--oj --direct --auto" -- "$cur") )
      ;;
    new)
      # only contest/task positional args; nothing useful to complete
      COMPREPLY=()
      ;;
    cookie-import)
      COMPREPLY=( $(compgen -f -- "$cur") )
      ;;
    *)
      COMPREPLY=()
      ;;
  esac
}
complete -F _ac ac
