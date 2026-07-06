# 双设备接力开发流程

Altium 文件多为二进制，无法可靠合并。同一时间只允许一台设备修改工程；切换设备前必须保存、关闭 Altium、提交并推送。

## 每次开始

```powershell
git status
git pull --rebase
```

只有工作区干净时才执行 `pull --rebase`。如有未提交修改，先提交或确认不再需要后再处理。

## 每次结束

1. 在 Altium 中按两次 `Esc`，执行 `File → Save All`，然后关闭 Altium。
2. 检查并提交：

```powershell
git status
git add -A
git status
git commit -m "Describe completed work"
git push
```

3. 在另一台设备开始工作前，再执行一次 `git pull --rebase`。

## 二进制冲突

不要同时编辑同一个 `.SchDoc`、`.PcbDoc` 或库文件。若发生冲突，先备份两边文件，然后明确选择一台设备的完整版本；不要尝试逐行合并二进制文件。

## 分支

个人接力开发直接使用 `main` 即可。只有需要保留实验性修改时才创建短期分支：

```powershell
git switch -c experiment/name
```

实验确认后再合并回 `main`。
