# dotfiles

## 芝士什么
Linux 中最前带有 `.` 的文件为隐藏文件，其中有一些是配置文件，将这些文件集中管理并通过 ln 软连接到它们应该在的位置，通过这种方式实现更方便迁移的配置文件管理

## Notice
这里只包括了 `~` 下的部分配置文件，`.config` 中的本身就在一个统一的文件夹里的配置文件就不管了

关于 zsh，市面上多数配置都会采用 Oh My Zsh 辅以许多插件和主题，虽然酷炫，但却臃肿且龟速，虽然存在优化方法（如 zinit 等延迟加载的插件管理器），但其实直接采用 pure zsh 加上少数所需插件就足够了。

## 食用方法
```bash
cd ~
git clone --recurse-submodules https://github.com/crd2333/dotfiles.git # unified management
ls -al # dotted files will be hidden in regular `ls`
# if in Linux
ln -s /home/<user>/dotfiles/.zsh/.zshrc ~/.zshrc
ln -s /home/<user>/dotfiles/.tmux.conf ~/.tmux.conf
ln -s /home/<user>/dotfiles/.gitconfig ~/.gitconfig
ln -s /home/<user>/dotfiles/.condarc ~/.condarc
# if in Windows
cp ./Microsoft.PowerShell_profile.ps1 ~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```