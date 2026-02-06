# dotfiles

## 芝士什么 What's this?
Linux 中最前带有 `.` 的文件为隐藏文件，其中有一些是配置文件，将这些文件集中管理并通过 `ln` 软连接到它们应该在的位置，通过这种方式实现更方便迁移的配置文件管理

In linux, files with `.` at the beginning are hidden files, some of which are configuration files. By managing these files in a centralized way and linking them to their appropriate locations using `ln` symbolic links, we can achieve more convenient migration of configuration file management.

## 注意 Notice
### zsh
市面上多数配置都会采用 Oh My Zsh 辅以许多插件和主题，虽然酷炫，但却臃肿且龟速，虽然存在优化方法（如 `zinit` 等延迟加载的插件管理器），但依旧显得冗余。其实直接采用 pure zsh 加上少数所需插件就足够了（不过，这种 manual install 方式需要手动 git clone 那些插件的整个仓库，为了保持更新，我采用 submodule 方式管理），并通过自定义插件来实现 oh-my-zsh 中的某些特性。

Most users use **Oh My Zsh with many plugins and themes** as their configurations. Although it looks cool, it is bloated and slow. Although there are optimization methods (such as `zinit` and other lazy-loading plugin managers), it still seems redundant. In fact, using **pure zsh** with a few necessary plugins is enough (however, this manual install method requires manually git cloning the entire repository of those plugins. To keep them updated, I use submodule for management), and custom plugins to achieve some features in oh-my-zsh.

### powershell
暂未探索抛弃 oh-my-posh、纯自定义的设置，除了 conda 初始化有些慢以外还算好用（conda 直接做成用命令延迟、按需加载了，毕竟不怎么在 windows 上跑 Python）。

Mothed without oh-my-posh and use pure custom settings has not been explored yet. Except for the conda initialization being a bit slow, it works well (conda is made to use command delay and on-demand loading, after all, I don't run Python much on Windows).

## 食用方法 How to use?
```bash
cd ~
git clone --recurse-submodules --shallow-submodules https://github.com/crd2333/dotfiles.git
ls -al # dotted files will be hidden in regular `ls`
# if in Linux
. ./create_symlink.sh
# if in Windows (PowerShell)
.\create_symlink.ps1
```

如果 clone 时忘记加子模块参数，则 (if forgot to add submodule parameters when cloning, then)：
```bash
git submodule update --init --recursive --depth 1
```

或手动按需创建软链接 (or manually create symlinks by need)：
```bash
# if in Linux
ln -s /home/<user>/dotfiles/.zsh/.zshrc ~/.zshrc
ln -s /home/<user>/dotfiles/.tmux.conf ~/.tmux.conf
ln -s /home/<user>/dotfiles/.gitconfig ~/.gitconfig
ln -s /home/<user>/dotfiles/.condarc ~/.condarc
ln -s /home/<user>/dotfiles/config ~/.config
# if in Windows (PowerShell)
New-Item -ItemType SymbolicLink -Path "D:\文档\PowerShell\Microsoft.PowerShell_profile.ps1" -Target ".\Microsoft.PowerShell_profile.ps1"
# or in cmd
# mklink "D:\文档\PowerShell\Microsoft.PowerShell_profile.ps1" ".\Microsoft.PowerShell_profile.ps1"
```
