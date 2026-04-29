#compdef blastshield

_blastshield() {
    local -a opts profiles agents
    opts=(
        {-p,--profile}'[Load additional profile]:profile:->profiles'
        --no-detect'[Disable auto-detection of cloud profiles]'
        {-c,--clean-env}'[Strip environment variables]'
        {-v,--verbose}'[Verbose output]'
        --violations'[Show recent sandbox violations]'
        --status'[Show detected CLIs and profiles]'
        --version'[Show version]'
        {-h,--help}'[Show help]'
    )
    profiles=(base secrets terraform gcloud aws azure kubectl gh)
    agents=(claude codex opencode gemini bash zsh)

    _arguments -C "$opts" '*:command:->commands'

    case $state in
        profiles)
            _describe 'profile' profiles
            ;;
        commands)
            _describe 'agent/command' agents
            ;;
    esac
}

_blastshield "$@"
