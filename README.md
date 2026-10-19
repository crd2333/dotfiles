# dotfiles

## 芝士什么 What's this?
Linux 中最前带有 `.` 的文件为隐藏文件，其中有一些是配置文件，将这些文件集中管理并通过 `ln` 软连接到它们应该在的位置，通过这种方式实现更方便迁移的配置文件管理

In linux, files with `.` at the beginning are hidden files, some of which are configuration files. By managing these files in a centralized way and linking them to their appropriate locations using `ln` symbolic links, we can achieve more convenient migration of configuration file management.

## JSON 配置合并

Pi 的 `settings.json`、`models.json` 和 `extensions/pi-crd233/pi-crd233.json` 不做软链接，由 `merge_json.mjs` 生成实际文件。Linux / Windows 的 setup 脚本都会调用它，也可以单独运行：

```bash
node ~/dotfiles/merge_json.mjs --dry-run
node ~/dotfiles/merge_json.mjs
```

按文件区分两种生成策略：

- `settings.json` 使用 `merge`：目标现有内容 → 公共 JSON → 同目录的 `settings.local.json`，保留 Pi 写入的 `deviceId`、`packages`、`lastChangelogVersion` 等目标独有键。
- `models.json` 和 `pi-crd233.json` 使用 `replace`：仅由公共 JSON → 同目录的 `*.local.json` 完整生成，不继承目标内容。公共配置或 local 中删除的键会从生成结果中消失，避免 breaking changes 后残留旧结构。

各层之间对象递归合并，数组和标量整体替换，local 优先级最高。已有的目标软链接会转换为普通文件，不会把生成结果写回受版本控制的源文件。

**首次使用 `replace` 策略前，请备份现有目标文件，并将其中需要保留的凭据、本机配置迁入对应的 `*.local.json`。只存在于目标中的值会被清除。** 从公共配置删除的旧字段也应从 local 中移除，否则 local 会再次加入这些字段。

`pi-crd233` 的公共配置位于 `config/pi/extensions/pi-crd233/pi-crd233.json`，API key、代理地址等本机配置放在同目录的 `pi-crd233.local.json`（已被 Git 忽略）。迁移机器时统一迁移 dotfiles 中的 local 文件，再运行 merge。插件只读取生成的 `~/.pi/agent/extensions/pi-crd233/pi-crd233.json`，不读取 local 文件或旧的 private 文件。

升级旧部署时，先把 `pi-crd233.private.json` 中的值迁入 `pi-crd233.local.json`（若 local 已存在，合并而不是覆盖），运行 merge 并确认凭据/代理已进入目标文件，再删除旧 private 文件及软链接。包含凭据的 local 和生成文件应设置为仅当前用户可读写（Linux 使用 `chmod 600`；Windows 使用对应的 ACL）。脚本不会自动迁移或删除旧 private 文件。

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
New-Item -ItemType SymbolicLink -Path $PROFILE -Target ".\posh\Microsoft.PowerShell_profile.ps1"
# or in cmd (replace $PROFILE with the actual path, e.g. C:\Users\<user>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
# mklink "C:\Users\<user>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" ".\posh\Microsoft.PowerShell_profile.ps1"
```
