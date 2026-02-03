
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/mf/miniconda3/bin/conda
    eval /home/mf/miniconda3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/home/mf/miniconda3/etc/fish/conf.d/conda.fish"
        . "/home/mf/miniconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/mf/miniconda3/bin" $PATH
    end
end
# <<< conda initialize <<<

