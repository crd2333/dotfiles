# Antigravity CLI (agy) wrapper with proxy support and per-conversation model restore on resume.
# Sourced from zsh/.zshrc (expects _coding_agent_with_proxy to be defined).

_agy_resume_model() {
    emulate -L zsh
    (( $# == 0 )) && return 1

    local first_arg="" arg
    for arg in "$@"; do
        [[ $arg == --no-proxy || $arg == --no_proxy ]] && continue
        first_arg=$arg
        break
    done
    case "$first_arg" in
        acp|agent|agents|changelog|help|install|mcp|mic-serve|models|plugin|plugins|remote-control|update)
            return 1
            ;;
    esac

    local has_explicit_model=0 use_continue=0 conv_id="" settings_val="" settings_raw=""
    local i=1
    while (( i <= $# )); do
        arg=${argv[i]}
        [[ $arg == -- ]] && break
        case "$arg" in
            --no-proxy|--no_proxy)
                ;;
            -h|--help|-help)
                return 1
                ;;
            --model|-model)
                has_explicit_model=1
                (( i++ ))
                ;;
            --model=*|-model=*)
                has_explicit_model=1
                ;;
            --settings|-settings|--settings=*|-settings=*)
                if [[ $arg == *=* ]]; then
                    settings_val=${arg#*=}
                elif (( i < $# )); then
                    (( i++ ))
                    settings_val=${argv[i]}
                else
                    settings_val=""
                fi
                if [[ -n $settings_val ]]; then
                    if [[ -r $settings_val ]]; then
                        settings_raw=$(<"$settings_val") 2>/dev/null
                    else
                        settings_raw=$settings_val
                    fi
                    if [[ $settings_raw =~ '"model"[[:space:]]*:[[:space:]]*"[^"]+"' ]]; then
                        has_explicit_model=1
                    fi
                fi
                ;;
            -c|-continue|--continue)
                use_continue=1
                ;;
            -r=*|-resume=*|--resume=*|-conversation=*|--conversation=*)
                conv_id=${arg#*=}
                ;;
            -r|-resume|--resume|-conversation|--conversation)
                if (( i < $# )) && [[ ${argv[i+1]} != -* ]]; then
                    (( i++ ))
                    conv_id=${argv[i]}
                fi
                ;;
            -p|-print|--print|-prompt|--prompt|-i|-prompt-interactive|--prompt-interactive|-add-dir|--add-dir|-agent|--agent|-effort|--effort|-input-format|--input-format|-json-schema|--json-schema|-log-file|--log-file|-mode|--mode|-output-format|--output-format|-print-timeout|--print-timeout|-project|--project)
                (( i++ ))
                ;;
        esac
        (( i++ ))
    done

    (( has_explicit_model )) && return 1

    if [[ -z $conv_id ]] && (( use_continue )); then
        local cache_path="${HOME}/.gemini/antigravity-cli/cache/last_conversations.json"
        if [[ -r $cache_path ]]; then
            local target_cwd=${PWD%/}
            [[ -z $target_cwd ]] && target_cwd="/"
            local escaped_cwd=${target_cwd//\\/\\\\}
            escaped_cwd=${escaped_cwd//\"/\\\"}
            local raw_cache="" key="" rest=""
            raw_cache=$(<"$cache_path") 2>/dev/null || return 1
            for key in "\"${escaped_cwd}\"" "\"${escaped_cwd}/\""; do
                if [[ $raw_cache == *"$key"* ]]; then
                    rest=${raw_cache#*"$key"}
                    if [[ $rest =~ '^[[:space:]]*:[[:space:]]*"([^"]+)"' ]]; then
                        conv_id=${match[1]}
                        break
                    fi
                fi
                [[ $target_cwd == "/" ]] && break
            done
        fi
    fi

    [[ -z $conv_id ]] && return 1

    local transcript_path="${HOME}/.gemini/antigravity-cli/brain/${conv_id}/.system_generated/logs/transcript.jsonl"
    [[ -r $transcript_path ]] || return 1

    local awk_prog='index($0, "\"type\":\"PLANNER_RESPONSE\"") {
        if (match($0, /"type":"PLANNER_RESPONSE"[^\{]*"model":"[^"]+"/)) {
            s = substr($0, RSTART, RLENGTH)
            sub(/^.*"model":"/, "", s)
            sub(/"$/, "", s)
            last = s
        }
    }
    END { if (last != "") print last }'

    local model=""
    model=$(command tail -c 524288 "$transcript_path" 2>/dev/null | command awk "$awk_prog" 2>/dev/null)
    if [[ -z $model ]]; then
        model=$(command awk "$awk_prog" "$transcript_path" 2>/dev/null)
    fi
    [[ -n $model ]] || return 1
    print -r -- "$model"
}

# agy with proxy and per-conversation model restore on resume
# (use --no-proxy or --no_proxy to force skipping system proxy)
agy() {
    local restored_model=""
    restored_model=$(_agy_resume_model "$@")
    if [[ -n $restored_model ]]; then
        local is_headless=0 arg
        for arg in "$@"; do
            [[ $arg == -- ]] && break
            case "$arg" in
                -p|-print|--print|-prompt|--prompt|--print=*|--prompt=*|-print=*|-prompt=*)
                    is_headless=1
                    break
                    ;;
            esac
        done
        if (( ! is_headless )) && [[ ${1-} != acp ]]; then
            echo "Restoring session model: ${restored_model}" >&2
        fi
        _coding_agent_with_proxy agy '^(help|-h|--help|--version)$' --model "$restored_model" "$@"
    else
        _coding_agent_with_proxy agy '^(help|-h|--help|--version)$' "$@"
    fi
}
