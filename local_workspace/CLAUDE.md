# AutoCircuit 实验工作区（本地 Claude Code 会话）

你运行在用户的 Windows 电脑上（Git Bash），工作目录是 `C:\Users\Timmy\AutoCircuit_Results`——
用户的电路实验记录本。用户用中文交流，是 UCSD 硕士生，在做 ECE 203（Cadence Virtuoso，IBM cmrf7sf PDK，
服务器 ieng6）。用户说自己软件基础和器件物理基础都不扎实：讲清楚，别只甩结果。

## 开工前
1. 代码仓库在 `C:\Users\Timmy\AutoCircuit`（GitHub TimmyXu015/AutoCircuit，**公开**）。先 `git -C ../AutoCircuit pull`；
   不存在就 `git clone https://github.com/TimmyXu015/AutoCircuit.git ../AutoCircuit`。
2. 读 `../AutoCircuit/docs/automation_playbook.json`：服务器路径、run.sh 和各 job、SKILL 框架、
   验证过的 ADE L API、踩过的坑。playbook 里"通过 MATLAB MCP 的 system() 去 ssh"是**云端会话**的绕路，
   本地会话直接用下面的工具。
3. 看 `LOG.md`，知道已经做过哪些实验。
4. 如果 `../AutoCircuit/local_workspace/` 里的 CLAUDE.md 或 `_tools/` 比这里的新，把它们复制过来（这里是副本）。

## 本地怎么干活
| 要做的事 | 命令 |
|---|---|
| 在服务器上跑 job（`batch/<job>.il`） | `bash _tools/acrun.sh <job>`（一般 < 2 分钟；Bash 超时设到 10 分钟） |
| GUI / 很长的 job | `bash _tools/acrun.sh --bg <job>`，之后 `bash _tools/acrun.sh --poll <job>` 直到出现 `[run] status:` |
| 服务器上任意命令 | `bash _tools/acrun.sh --ssh "<cmd>"`（免密钥 ssh：lix015@ieng6-ece-10.ucsd.edu，Cadence 命令要包 `bash -lc '...'`） |
| 取回数据 | `bash _tools/fetch.sh <日期>_<job>_<描述> AutoCircuit_results/<file>.csv ...` → `_raw/<实验>/` |
| 画图 | 绘图脚本放 `_raw/<实验>/`（同时在仓库 `matlab/` 留一份），`bash _tools/plot.sh _raw/<实验>/<x>_plot.m` |
| 改 SKILL / 加 job | 在 `../AutoCircuit` 改 → commit → push（服务器上的 run.sh 每次先 git pull）。加 job 的三处见 playbook `skill_framework.add_a_job` |

- MATLAB：`matlab -batch "..."`（R2025b 在 PATH 上）。绘图脚本用 `here = fileparts(mfilename('fullpath'))` 读数据，
  PNG 写到实验文件夹：`[~,e]=fileparts(here); out=fullfile(fileparts(fileparts(here)),e)`，`exportgraphics(..., 'Resolution', 130)`。
- 要看图就用 Read 工具打开 PNG 自己检查一遍再交给用户。
- git push 第一次可能弹出 GitHub 登录窗口：让用户自己登录。commit 用户名/邮箱没配置时，问用户，不要乱填。

## 记录本规则（这个文件夹）
- `LOG.md`：总目录，每个实验一行：`| 日期 | [标题](<实验>/log.md) | 图名 |`（标题里的 `|` 写成 `\|`）。
- `<YYYY-MM-DD>_<job>_<描述>/`：**只放 `log.md` 和 PNG**。
- `log.md` 格式：`# 标题`，一行 `` `<实验>` · 原始数据与脚本：`_raw/<实验>/` ``，然后要点：电路 / 仿真 / 运行 / 图（每张一句）/ 记录（数据里看到的事实，或某个量怎么读）。
- `_raw/<实验>/`：CSV、绘图脚本、文本报告、模型文件副本、netlist。
- **绝不删除这个文件夹里的任何东西**，删由用户自己来。挪动可以。

## 规矩
- **作业由用户自己推理**：给工具、数据、图，告诉他在哪读、怎么读；不给最终答案，除非用户明确把那部分交给你。
- 服务器上用户经常开着自己的 GUI Virtuoso（占着锁和 spectre 会话）。**不经同意不杀用户的进程。**
- 仓库公开：不放密钥、不放 IBM 模型文件内容（文件头写着 IBM CONFIDENTIAL，副本只能放 `_raw`）、不放作业结果。
- 学到新东西（能用的 API、修复、坑）写进仓库 playbook，和代码同一个 commit。
- 回复简短：做了什么、图在哪、怎么读。每个实验结束时：log.md + PNG + LOG.md 一行。
