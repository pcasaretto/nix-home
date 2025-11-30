dev() {
    local cmd="$1"
    shift
    case "$cmd" in
        cd)
            local src_root="$HOME/src"
            local target
            
            # Check if src_root exists
            if [[ ! -d "$src_root" ]]; then
                echo "Error: $src_root does not exist."
                return 1
            fi

            if [[ -n "$1" ]]; then
                # Check for exact directory name match
                # We use -g to match the name exactly (glob pattern)
                # This avoids fzf if there is exactly one directory with this name
                local exact_matches
                exact_matches=("${(@f)$(fd -t d -g "$1" "$src_root")}")
                
                if [[ ${#exact_matches[@]} -eq 1 ]]; then
                    target="${exact_matches[1]}"
                else
                    # Fallback to fzf
                    # --select-1: automatically select if only one match
                    # --exit-0: exit if no match
                    target=$(fd -t d . "$src_root" | fzf --query "$*" --select-1 --exit-0)
                fi
            else
                target=$(fd -t d . "$src_root" | fzf)
            fi

            if [[ -n "$target" ]]; then
                cd "$target"
            fi
            ;;
        *)
            echo "Usage: dev cd [directory]"
            return 1
            ;;
    esac
}

_dev() {
    local -a commands
    commands=('cd:Fuzzy cd into ~/src')
    
    _arguments -C \
        '1: :->cmds' \
        '*:: :->args'

    case "$state" in
        cmds)
            _describe -t commands 'commands' commands
            ;;
        args)
            case $line[1] in
                cd)
                    _path_files -W "$HOME/src" -/
                    ;;
            esac
            ;;
    esac
}

compdef _dev dev
