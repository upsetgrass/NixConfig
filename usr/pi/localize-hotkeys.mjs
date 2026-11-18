import { readFileSync, writeFileSync } from "node:fs";

const actions = new Map([
  ["Move cursor / browse history", "移动光标 / 浏览输入历史"],
  ["Move by word", "按单词移动"],
  ["Start of line", "跳到行首"],
  ["End of line", "跳到行尾"],
  ["Jump forward to character", "向右查找并跳到指定字符"],
  ["Jump backward to character", "向左查找并跳到指定字符"],
  ["Scroll by page", "按页滚动"],
  ["Send message", "发送消息"],
  ["New line", "换行"],
  ["Delete word backwards", "删除光标前的单词"],
  ["Delete word forwards", "删除光标后的单词"],
  ["Delete to start of line", "删除到行首"],
  ["Delete to end of line", "删除到行尾"],
  ["Paste the most-recently-deleted text", "粘贴最近删除的文本"],
  ["Cycle through the deleted text after pasting", "粘贴后切换到更早删除的文本"],
  ["Undo", "撤销"],
  ["Path completion / accept autocomplete", "补全路径 / 接受当前建议"],
  ["Cancel autocomplete / abort streaming", "取消补全 / 停止生成"],
  ["Clear editor (first) / exit (second)", "第一次按清空输入，第二次按退出"],
  ["Exit (when editor is empty)", "退出（输入框为空时）"],
  ["Suspend to background", "挂起到后台"],
  ["Cycle thinking level", "循环切换推理强度"],
  ["Cycle models", "循环切换模型"],
  ["Open model selector", "打开模型选择器"],
  ["Toggle tool output expansion", "展开或折叠工具输出"],
  ["Toggle thinking block visibility", "显示或隐藏思考内容"],
  ["Edit message in external editor", "在外部编辑器中编辑消息"],
  ["Copy selection or last assistant message", "复制选中的文本或助手的上一条回复"],
  ["Queue follow-up message", "将后续消息加入队列"],
  ["Restore queued messages", "把排队的消息移回输入框"],
  ["Paste files on macOS, images, or text from clipboard", "从剪贴板粘贴图片、文本或文件（仅 macOS 支持粘贴文件）"],
  ["Slash commands", "打开斜杠命令菜单"],
  ["Run bash command", "运行 Bash 命令"],
  ["Run bash command (excluded from context)", "运行 Bash 命令（不加入对话上下文）"],
]);

const tableHeader = "| Key | Action |";
const mainTables = /\*\*Navigation\*\*\n\| Key \| Action \|[\s\S]*?\n(?=`)/g;
const extensionTable = `**Extensions**\n${tableHeader}`;

function localize(file) {
  const source = readFileSync(file, "utf8");
  if ([...source.matchAll(mainTables)].length !== 1 || source.split(extensionTable).length !== 2) {
    throw new Error(`Pi /hotkeys tables changed in ${file}`);
  }

  const translated = new Set();
  const output = source
    .replace(mainTables, (tables) => tables
      .replaceAll(tableHeader, "| Key | 操作 |")
      .replace(/^(\| \\`.*? \| )([^$\n]+?)(\$\{.*\})? \|$/gm, (_line, keys, label, suffix = "") => {
        const translation = actions.get(label);
        if (!translation) throw new Error(`Missing /hotkeys translation for ${label} in ${file}`);
        translated.add(label);
        return `${keys}${translation}${suffix.replace(" (Ctrl+Enter on Windows Terminal)", "（Windows Terminal 中使用 Ctrl+Enter）")} |`;
      }))
    .replace(extensionTable, "**Extensions**\n| Key | 操作 |");
  if (translated.size !== actions.size) throw new Error(`Pi /hotkeys action list changed in ${file}`);
  writeFileSync(file, output);
}

for (const file of process.argv.slice(2)) localize(file);
