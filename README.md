# dotfiles

## 芝士什么
Linux 中最前带有 `.` 的文件为隐藏文件，其中有一些是配置文件，将这些文件集中管理并通过 ln 软连接到它们应该在的位置，通过这种方式实现更方便迁移的配置文件管理

## Notice
我这里只包括了 `~` 下的部分配置文件，`.config` 中的本身就在一个统一的文件夹里的配置文件就不管了

## 食用方法
```
git clone https://github.com/crd2333/dotfiles.git
cd dotfiles
git submodule init
git submodule update
```