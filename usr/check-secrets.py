#!/usr/bin/env python3
import pathlib
import re
import subprocess


# 仓库根目录；默认检查 ~/work/NixConfig，也可以通过第一个参数指定
ROOT = pathlib.Path.home() / "work" / "NixConfig"


def git(*args):
    # 统一执行只读 Git 命令；任何命令失败都会中止检查
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


# 常见密钥形态；只报告文件、行号和类别，绝不打印命中内容
RULES = {
    # PEM / OpenPGP 私钥块
    "私钥块": r"-----BEGIN (?:[A-Z0-9]+ )*(?:PRIVATE KEY|PGP PRIVATE KEY BLOCK)-----",
    # 常见服务令牌格式
    "服务令牌": r"(?<![\w-])(?:sk-(?:proj-|svcacct-|ant-|or-v1-)?[A-Za-z0-9_-]{20,}|sk_(?:live|test)_[A-Za-z0-9]{16,}|(?:gh[pousr]_[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,})|glpat-[A-Za-z0-9_-]{15,}|xox[baprs]-[A-Za-z0-9-]{12,}|AIza[0-9A-Za-z_-]{35}|(?:AKIA|ASIA)[A-Z0-9]{16}|npm_[A-Za-z0-9]{25,}|hf_[A-Za-z0-9]{25,}|pypi-[A-Za-z0-9_-]{30,}|gsk_[A-Za-z0-9]{25,})(?![\w-])",
    # URL 中内嵌用户名和密码
    "URL内嵌凭据": r"\b(?:https?|socks[45]h?|postgres(?:ql)?|mysql|mongodb(?:\+srv)?|redis|ftp|amqps?)://[^\s/@:]+:[^\s/@<>\x22\x27]+@",
    # 明文字面量 Bearer 令牌
    "Bearer字面量": r"(?i)\bbearer[ \t]+[a-z0-9_./+\-=]{16,}",
    # JWT 三段式结构
    "JWT": r"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{10,}\b",
    # URL 查询串中的凭据参数
    "查询参数凭据": r"(?i)[?&](?:api[_-]?key|access[_-]?token|secret|password|token|signature)=[a-z0-9_%/+.=-]{6,}",
}

# 通用密钥字段赋值检测，覆盖脚本、JSON、Nix 和配置文件中的常见写法
ASSIGN = re.compile(
    r'''(?ix)(?<![\w-])
        (?:[\w-]*[_-])?
        (?P<field>api[_-]?key|access[_-]?key(?:[_-]?id)?|secret(?:[_-]?key)?|
          (?:access|refresh|auth|oauth|session|bot|github|gitlab|npm|hf|pypi)[_-]?token|
          token|client[_-]?secret|pass(?:word|wd|phrase)|private[_-]?key|authorization|cookie)
        \b["']?\s*(?:=|:)\s*
        (?:"(?P<double>[^"\r\n]*)"|'(?P<single>[^'\r\n]*)'|(?P<bare>[^\s,;\]}]+))
    '''
)

# 常见示例值与占位符；匹配到这些值时不报告
PLACEHOLDER = {
    "true", "false", "null", "none", "empty", "dummy", "changeme", "change_me",
    "password", "token", "openai", "ollama", "example", "placeholder", "your",
    "fake", "test", "replace", "redacted", "xxx", "xxxx", "xxxxxx",
}


def is_literal(value, group):
    # 过滤空值、占位符以及环境变量、命令和文件路径引用
    value = value or ""
    if not value or value.casefold() in PLACEHOLDER:
        return False
    if value.startswith(("$", "!", "<", "~", "/", "./", "{", "[", "(", "`")):
        return False
    if group == "bare" and not re.fullmatch(r"[A-Za-z0-9_./+@%=-]{6,}", value):
        return False
    if re.fullmatch(
        r"(?:example|placeholder|your|fake|dummy|test|replace|redacted|change[_-]?me|xxx+)(?:[_-].*)?",
        value,
        re.I,
    ):
        return False
    return True


reported = set()


def scan(scope, path, data):
    # 二进制文件不做文本匹配，避免误报；检查结果不包含原始行内容
    if b"\0" in data:
        return
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return

    for line_number, line in enumerate(text.splitlines(), 1):
        for kind, pattern in RULES.items():
            if re.search(pattern, line):
                reported.add((scope, path, line_number, kind))

        for match in ASSIGN.finditer(line):
            for group in ("double", "single", "bare"):
                if match[group] is not None:
                    if is_literal(match[group], group):
                        reported.add(
                            (scope, path, line_number, "赋值语句:" + match["field"].lower())
                        )
                    break


# 1. 检查工作区文件，包括未跟踪文件；跳过 .git 内部和符号链接
for path in ROOT.rglob("*"):
    relative = path.relative_to(ROOT)
    if ".git" in relative.parts or path.is_symlink() or not path.is_file():
        continue
    scan("工作区", str(relative), path.read_bytes())

# 2. 收集 Git 索引以及全部分支、标签和 reflog 可达历史中的文件对象
blobs = {}
for row in git("ls-files", "-s", "-z").split(b"\0"):
    if not row:
        continue
    metadata, name = row.split(b"\t", 1)
    mode, object_id, _ = metadata.decode().split()
    if mode.startswith("100"):
        blobs.setdefault(object_id, []).append(("索引", name.decode()))

commits = git("rev-list", "--all", "--reflog").decode().splitlines()
for commit in commits:
    for row in git("ls-tree", "-rz", commit).split(b"\0"):
        if not row:
            continue
        metadata, name = row.split(b"\t", 1)
        mode, object_type, object_id = metadata.decode().split()
        if object_type == "blob" and mode.startswith("100"):
            entry = ("历史", name.decode())
            paths = blobs.setdefault(object_id, [])
            if entry not in paths:
                paths.append(entry)

for object_id, paths in blobs.items():
    content = git("cat-file", "blob", object_id)
    for scope, path in paths:
        scan(scope, path, content)

# 输出只含范围、文件路径、行号和命中类别，不显示密钥原文
if reported:
    for scope, path, line_number, kind in sorted(reported):
        print(f"{scope} {path}:{line_number} {kind}")
    print(f"发现 {len(reported)} 个待人工核实的命中；规则匹配不等同于确认存在有效密钥。")
else:
    print("未发现符合内置规则的文本命中。")
print(f"已检查工作区文本，以及 {len(commits)} 个本地 Git 提交可达的历史文件。")
print("注意：此脚本是启发式检查，不是完整的密钥扫描器；不检查二进制内容、符号链接目标、Git LFS 外部对象或远端未获取的历史。")
