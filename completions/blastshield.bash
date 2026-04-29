# bash completion for blastshield
_blastshield() {
    local cur prev opts profiles
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--profile --no-detect --clean-env --verbose --violations --status --version --help -p -c -v -h"
    profiles="base secrets terraform gcloud aws azure kubectl gh"

    case "$prev" in
        -p|--profile)
            COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
        return 0
    fi

    # Suggest common AI agents
    COMPREPLY=($(compgen -W "claude codex opencode gemini bash zsh" -- "$cur"))
}
complete -F _blastshield blastshield
