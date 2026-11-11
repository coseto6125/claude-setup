# The live implementation is the Rust port in ~/.claude/native/auto-etoon (src/cap.rs); this file is the spec and the differential oracle. A behaviour change goes to both.
"""Shell-aware verdict on the cargo commands in a Bash command. Run with `python3 -I`.

  cargo_test_cap.py CMD          print CMD with --test-threads=4 added to every uncapped
                                 `cargo test|t` / `cargo nextest run|r` invocation; exit 0 only when
                                 every such invocation ends capped, otherwise exit 1 and print nothing
  cargo_test_cap.py --check CMD  print "<compiles> <caps>": compiles = 1 when CMD runs a compiling
                                 cargo subcommand, caps = ok when the rewrite above would exit 0

This file is the one authority for guard-cargo-disk.sh (decide) and the Bash hook's --pre rewriter (rewrite).

An invocation counts only in command position: at the start, after an unquoted operator, after
VAR=value, env, time, nice and the like, after `cd x &&`, inside ( ) and { }, and inside the body of
`sh|bash|zsh -c` or `eval`. A cargo word that is an argument (`echo cargo test`, `grep -c "cargo test"`),
a comment, or heredoc text does not count. An invocation is capped, rewritable (insert the cap), or
unknown (cap cannot be placed, for example inside `$'...'`, `$(...)`, or after a cargo option this
file cannot parse); an unknown test invocation makes the verdict "fail".

WHY a text scan cannot be complete: a command word built at run time (`c=cargo; "$c" test`), a script,
an alias or a shell function hides the cargo word from any scan of the command text. This file blocks
a dynamic command word that has an argument `test`, `t` or `nextest`; the rest needs a limit at run time.
"""
import re
import sys

CAP = "--test-threads=4"
COMPILING = {"build", "b", "test", "t", "check", "c", "clippy", "nextest", "run", "r", "bench", "install", "doc", "d"}
CARGO_ANY_RE = re.compile(r"\bcargo\b")
CARGO_TEST_RE = re.compile(r"\bcargo\b[^|;&\n]*?\s(test|t|nextest)\b")
ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\+?=")
THREADS_RE = re.compile(r"[1-9][0-9]*")
NEXTEST_J_RE = re.compile(r"^-j=?\d+$")

REDIR = {">", ">>", ">&", ">|", "&>", "&>>", "<", "<<", "<<-", "<<<", "<&", "<>"}
CTRL = {"|", "||", "|&", "&", "&&", ";", ";;", ";&", ";;&", "(", ")", "\n"}
OPS3 = ("<<<", "<<-", "&>>", ";;&")
OPS2 = ("&&", "||", "|&", ";;", ";&", ">>", ">&", ">|", "&>", "<<", "<&", "<>")
RESERVED = {"{", "}", "!", "if", "then", "else", "elif", "while", "until", "do", "fi", "done", "esac"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "ash"}
# simple wrappers -> (options that take a value, number of positional words before the command); EXEC_WRAPPERS below parse more options
WRAPPERS = {
    "time": ({"-f", "-o", "--format", "--output"}, 0),
    "command": (set(), 0),
    "exec": ({"-a"}, 0),
    "nohup": (set(), 0),
    "setsid": (set(), 0),
    "builtin": (set(), 0),
    "nice": ({"-n", "--adjustment"}, 0),
    "timeout": ({"-s", "-k", "--signal", "--kill-after"}, 1),
    "rtk": (set(), 0),
}


class Spec:
    """Options of a wrapper that runs another command: single letters that are flags, single letters that
    take a value (attached or in the next word), letters whose value is optional and attached, long flags,
    long options that take a value, the positional words before the command, and the env it resets."""

    def __init__(self, flags="", valued="", attached="", longf=(), longv=(), positional=0, any_long=False,
                 resets_env=False, assigns=False):
        self.flags, self.valued, self.attached = set(flags), set(valued), set(attached)
        self.longf, self.longv = set(longf), set(longv)
        self.positional, self.any_long, self.resets_env, self.assigns = positional, any_long, resets_env, assigns


EXEC_WRAPPERS = {
    "sudo": Spec(flags="ABEHKPSVbehiklnsv", valued="CDRTUgprtu",
                 longf=("--askpass", "--background", "--bell", "--edit", "--help", "--login", "--list", "--non-interactive",
                        "--preserve-env", "--preserve-groups", "--remove-timestamp", "--reset-timestamp", "--set-home",
                        "--shell", "--stdin", "--validate", "--version"),
                 longv=("--chdir", "--chroot", "--close-from", "--command-timeout", "--group", "--host", "--login-class",
                        "--other-user", "--prompt", "--role", "--type", "--user"), resets_env=True, assigns=True),
    "doas": Spec(flags="ns", valued="uC", resets_env=True),
    "xargs": Spec(flags="0oprtx", valued="adEILnPs", attached="eil",
                  longf=("--exit", "--help", "--interactive", "--no-run-if-empty", "--null", "--open-tty", "--show-limits",
                         "--verbose", "--version"),
                  longv=("--arg-file", "--delimiter", "--eof", "--max-args", "--max-chars", "--max-lines", "--max-procs",
                         "--process-slot-var", "--replace", "--max-lines")),
    "stdbuf": Spec(valued="ioe", longv=("--input", "--output", "--error")),
    "ionice": Spec(flags="t", valued="cnpPu", longf=("--ignore", "--version", "--help"),
                   longv=("--class", "--classdata", "--pid", "--pgid", "--uid")),
    "chrt": Spec(flags="bfiordRavm", longf=("--batch", "--fifo", "--idle", "--other", "--rr", "--deadline",
                                              "--reset-on-fork", "--all-tasks", "--verbose"),
                 longv=("--sched-runtime", "--sched-deadline", "--sched-period"), positional=1),
    "taskset": Spec(flags="acp", longf=("--all-tasks", "--cpu-list", "--pid"), positional=1),
    "flock": Spec(flags="sxeunoF", valued="wE", longf=("--shared", "--exclusive", "--unlock", "--nonblock", "--nb",
                                                       "--no-fork", "--close"),
                  longv=("--timeout", "--wait", "--conflict-exit-code"), positional=1),
    "systemd-run": Spec(flags="tqSPG", valued="pEHMu",
                        longf=("--user", "--system", "--scope", "--wait", "--pty", "--pipe", "--collect", "--no-block",
                               "--same-dir", "--shell", "--quiet", "--remain-after-exit", "--no-ask-password",
                               "--no-pager", "--send-sighup"),
                        longv=("--unit", "--description", "--slice", "--property", "--setenv", "--uid", "--gid",
                               "--working-directory", "--service-type", "--nice", "--host", "--machine", "--after",
                               "--before", "--requires", "--wants", "--on-active", "--on-boot", "--on-startup",
                               "--on-calendar", "--timer-property"), resets_env=True),
    "unbuffer": Spec(flags="p"),
    "setpriv": Spec(longf=("--clear-groups", "--keep-groups", "--init-groups", "--no-new-privs", "--reset-env",
                           "--dump", "--list-caps"),
                    longv=("--reuid", "--regid", "--ruid", "--euid", "--rgid", "--egid", "--groups", "--inh-caps",
                           "--ambient-caps", "--bounding-set", "--securebits", "--pdeathsig", "--selinux-label",
                           "--apparmor-profile", "--landlock-access")),
    "firejail": Spec(any_long=True, resets_env=True),
    "caffeinate": Spec(flags="dimsu", valued="tw"),
}
# Runners that start cargo elsewhere on this host's CPUs: any `cargo test` among their words counts.
RUNNERS = {"docker", "podman", "ssh", "wsl", "wsl.exe"}

CARGO_VALUE_GLOBALS = {"-C", "-Z", "--config", "--color", "--explain"}
CARGO_FLAG_GLOBALS = {"-V", "--version", "-v", "--verbose", "-vv", "-vvv", "-q", "--quiet", "--locked",
                      "--offline", "--frozen", "--list", "-h", "--help"}
ANSI_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", "'": "'", '"': '"', "a": "\a", "b": "\b",
                "e": "\x1b", "f": "\f", "v": "\v"}


class Word:
    __slots__ = ("start", "end", "value", "dyn", "quoted", "substs", "pieces")

    def __init__(self, start):
        self.start = start
        self.end = start
        self.value = ""
        self.dyn = False  # holds an expansion or a glob: the value is not what the shell runs
        self.quoted = False
        self.substs = []  # (start, end) of each $(...), `...` or <(...) body, as indexes into the scanned text
        self.pieces = []  # (kind, plain): kind "q" quoted span, "b" bare text

    def single_plain_quote(self):
        return len(self.pieces) == 1 and self.pieces[0] == ("q", True)


class Op:
    __slots__ = ("text", "start")

    def __init__(self, text, start):
        self.text = text
        self.start = start


def find_close_paren(s, j):
    """Index of the ) that closes a ( opened just before j, or -1."""
    depth, n = 1, len(s)
    while j < n:
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == "'":
            j = s.find("'", j + 1)
            if j < 0:
                return -1
        elif c == '"':
            j = find_close_dquote(s, j + 1)
            if j < 0:
                return -1
        elif c == "`":
            j = find_backtick(s, j + 1)
            if j < 0:
                return -1
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1


def find_close_dquote(s, j):
    n = len(s)
    while j < n and s[j] != '"':
        if s[j] == "\\":
            j += 2
        elif s.startswith("$(", j):
            j = find_close_paren(s, j + 2)
            if j < 0:
                return -1
            j += 1
        else:
            j += 1
    return j if j < n else -1


def find_backtick(s, j):
    n = len(s)
    while j < n:
        if s[j] == "\\":
            j += 2
        elif s[j] == "`":
            return j
        else:
            j += 1
    return -1


class Lexer:
    def __init__(self, s):
        self.s = s
        self.i = 0
        self.toks = []
        self.cur = None
        self.err = False
        self.pending = []  # heredocs whose body starts after the next newline
        self.delim_strip = None
        self.hd_texts = []  # bodies of unquoted heredocs: the shell expands $(...) in them

    def begin(self):
        if self.cur is None:
            self.cur = Word(self.i)
        return self.cur

    def piece(self, kind, plain):
        w = self.begin()
        if kind == "b" and w.pieces and w.pieces[-1][0] == "b":
            return
        w.pieces.append((kind, plain))

    def end_word(self):
        w = self.cur
        if w is None:
            return
        w.end = self.i
        self.cur = None
        if self.delim_strip is not None:
            self.pending.append((w.value, w.quoted, self.delim_strip))
            self.delim_strip = None
        self.toks.append(w)

    def read_heredocs(self):
        s, n = self.s, len(self.s)
        for delim, quoted, strip in self.pending:
            body = []
            while self.i < n:
                end = s.find("\n", self.i)
                line = s[self.i : n if end < 0 else end]
                self.i = n if end < 0 else end + 1
                if (line.lstrip("\t") if strip else line) == delim:
                    break
                body.append(line)
            text = "\n".join(body)
            if not quoted and ("$(" in text or "`" in text):
                self.hd_texts.append(text)
        self.pending = []

    def run(self):
        s, n = self.s, len(self.s)
        while self.i < n and not self.err:
            c = s[self.i]
            if c in " \t":
                self.end_word()
                self.i += 1
            elif c == "\n":
                self.end_word()
                self.toks.append(Op("\n", self.i))
                self.i += 1
                self.read_heredocs()
            elif c == "#" and self.cur is None:
                end = s.find("\n", self.i)
                self.i = n if end < 0 else end
            elif c == "\\":
                if s.startswith("\n", self.i + 1):
                    self.i += 2
                else:
                    w = self.begin()
                    self.piece("b", False)
                    w.value += s[self.i + 1 : self.i + 2] or "\\"
                    w.quoted = True
                    self.i += 2
            elif c == "'":
                end = s.find("'", self.i + 1)
                if end < 0:
                    self.err = True
                    break
                w = self.begin()
                self.piece("q", True)
                w.value += s[self.i + 1 : end]
                w.quoted = True
                self.i = end + 1
            elif c == '"':
                self.dquote()
            elif c == "$":
                self.dollar()
            elif c == "`":
                end = find_backtick(s, self.i + 1)
                if end < 0:
                    self.err = True
                    break
                w = self.begin()
                self.piece("b", False)
                w.substs.append((self.i + 1, end))
                w.value += s[self.i : end + 1]
                w.dyn = True
                self.i = end + 1
            elif c in "|&;()<>":
                self.operator(c)
            else:
                w = self.begin()
                self.piece("b", False)
                w.value += c
                if c in "*?[":
                    w.dyn = True
                self.i += 1
        if not self.err:
            self.end_word()

    def dquote(self):
        s, n = self.s, len(self.s)
        w = self.begin()
        j, buf, plain = self.i + 1, [], True
        while j < n and s[j] != '"':
            ch = s[j]
            if ch == "\\" and j + 1 < n:
                plain = False
                nx = s[j + 1]
                if nx == "\n":
                    pass
                elif nx in '\\"$`':
                    buf.append(nx)
                else:
                    buf.append("\\" + nx)
                j += 2
            elif s.startswith("$(", j):
                end = find_close_paren(s, j + 2)
                if end < 0:
                    self.err = True
                    return
                w.substs.append((j + 2, end))
                buf.append(s[j : end + 1])
                w.dyn, plain = True, False
                j = end + 1
            elif ch == "`":
                end = find_backtick(s, j + 1)
                if end < 0:
                    self.err = True
                    return
                w.substs.append((j + 1, end))
                buf.append(s[j : end + 1])
                w.dyn, plain = True, False
                j = end + 1
            else:
                if ch == "$":
                    w.dyn, plain = True, False
                buf.append(ch)
                j += 1
        if j >= n:
            self.err = True
            return
        self.piece("q", plain)
        w.value += "".join(buf)
        w.quoted = True
        self.i = j + 1

    def dollar(self):
        s, n = self.s, len(self.s)
        w = self.begin()
        i = self.i
        if s.startswith("$(", i):
            end = find_close_paren(s, i + 2)
            if end < 0:
                self.err = True
                return
            w.substs.append((i + 2, end))
            w.value += s[i : end + 1]
            w.dyn = True
            self.piece("b", False)
            self.i = end + 1
        elif s.startswith("$'", i):
            j, buf = i + 2, []
            while j < n and s[j] != "'":
                if s[j] == "\\" and j + 1 < n:
                    esc = ANSI_ESCAPES.get(s[j + 1])
                    if esc is None:
                        w.dyn = True
                        esc = s[j : j + 2]
                    buf.append(esc)
                    j += 2
                else:
                    buf.append(s[j])
                    j += 1
            if j >= n:
                self.err = True
                return
            w.value += "".join(buf)
            w.quoted = True
            self.piece("q", False)
            self.i = j + 1
        elif s.startswith("${", i):
            end = s.find("}", i + 2)
            if end < 0:
                self.err = True
                return
            w.value += s[i : end + 1]
            w.dyn = True
            self.piece("b", False)
            self.i = end + 1
        else:
            w.value += "$"
            w.dyn = True
            self.piece("b", False)
            self.i += 1

    def operator(self, c):
        s = self.s
        i = self.i
        if c in "<>" and s.startswith("(", i + 1):
            end = find_close_paren(s, i + 2)
            if end < 0:
                self.err = True
                return
            w = self.begin()
            self.piece("b", False)
            w.substs.append((i + 2, end))
            w.value += s[i : end + 1]
            w.dyn = True
            self.i = end + 1
            return
        w = self.cur
        if c in "<>" and w is not None and w.value.isdigit() and not w.quoted and not w.dyn:
            self.cur = None  # `2>&1`: the digits are the fd of the redirection
        else:
            self.end_word()
        text = next((o for o in OPS3 if s.startswith(o, i)), None) or next((o for o in OPS2 if s.startswith(o, i)), c)
        self.toks.append(Op(text, i))
        self.i = i + len(text)
        if text in ("<<", "<<-"):
            self.delim_strip = text == "<<-"


def simple_commands(toks):
    """Group the words of each simple command. A redirection operand is not an argument."""
    cmds, words, operand = [], [], False
    for t in toks:
        if isinstance(t, Op):
            if t.text in REDIR:
                operand = True
            elif t.text in CTRL:
                if words:
                    cmds.append(words)
                words, operand = [], False
        elif operand:
            operand = False
        else:
            words.append(t)
    if words:
        cmds.append(words)
    return cmds


class Result:
    def __init__(self):
        self.compile = False
        self.unknown = False
        self.edits = []  # (index in the original text, inserted text)

    def parse_error(self, text):
        self.compile = self.compile or bool(CARGO_ANY_RE.search(text))
        self.unknown = self.unknown or bool(CARGO_TEST_RE.search(text))


def valid_threads(value):
    return value is not None and THREADS_RE.fullmatch(value) is not None


def analyze(s, base, can_rewrite, res, depth=0):
    if depth > 6:
        res.compile = res.unknown = True
        return
    lx = Lexer(s)
    lx.run()
    if lx.err:
        res.parse_error(s)
        return
    for body in lx.hd_texts:
        res.parse_error(body)
    for tok in lx.toks:
        if isinstance(tok, Word):
            for a, b in tok.substs:
                analyze(s[a:b], base + a, False, res, depth + 1)
    for words in simple_commands(lx.toks):
        command(words, s, base, can_rewrite, res, depth)


def bail(words, j, res):
    """A wrapper whose options this file cannot parse: a later `cargo test` is unknown; other cargo is compiling."""
    for k in range(j, len(words)):
        w = words[k]
        if w.dyn or w.value.rsplit("/", 1)[-1] != "cargo":
            continue
        nxt = words[k + 1].value if k + 1 < len(words) else ""
        res.compile = True
        if nxt in ("test", "t", "nextest") or nxt.startswith("+"):
            res.unknown = True


def skip_env(words, j, env, res):
    """Parse the arguments of `env` from index j; return the index of the command word, or None."""
    while j < len(words):
        w = words[j]
        v = w.value
        if v == "--":
            return j + 1
        if v in ("-i", "--ignore-environment", "-"):
            env.clear()
        elif v in ("-u", "--unset"):
            if j + 1 < len(words):
                env.pop(words[j + 1].value, None)
            j += 1
        elif v.startswith("--unset="):
            env.pop(v[8:], None)
        elif v.startswith("-u") and not v.startswith("--") and len(v) > 2:
            env.pop(v[2:], None)
        elif v in ("-C", "--chdir"):
            j += 1
        elif v in ("-0", "-v", "--null", "--debug") or v.startswith("--chdir="):
            pass
        elif v.startswith("-") and len(v) > 1:
            bail(words, j, res)  # -S and unknown options
            return None
        elif ASSIGN_RE.match(v) and not w.quoted:
            name, _, val = v.partition("=")
            env[name] = None if w.dyn else val
        else:
            return j
        j += 1
    return None


def skip_wrapper(name, words, i, res):
    valued, positional = WRAPPERS[name]
    j = i + 1
    while j < len(words) and words[j].value.startswith("-") and words[j].value != "-":
        opt = words[j].value
        if name == "command" and opt in ("-v", "-V"):
            return None
        if opt == "--":
            j += 1
            break
        j += 2 if opt in valued else 1
    if name == "rtk" and j < len(words) and words[j].value == "proxy":
        j += 1
    j += positional
    return j if j < len(words) else None


def skip_exec_wrapper(name, words, i, env, s, base, can_rewrite, res, depth):
    """Index of the command word behind a wrapper, or None when the command is handled here or unknown."""
    sp = EXEC_WRAPPERS[name]
    if sp.resets_env:
        env.clear()
    j = i + 1
    while j < len(words):
        v = words[j].value
        if v == "--":
            j += 1
            break
        if not v.startswith("-") or v == "-":
            break
        if v.startswith("--"):
            opt, has_value = v.split("=", 1)[0], "=" in v
            if sp.any_long or opt in sp.longf or (has_value and opt in sp.longv):
                j += 1
            elif opt in sp.longv:
                j += 2
            else:
                bail(words, j, res)
                return None
            continue
        step = 1
        for idx, ch in enumerate(v[1:], start=1):
            if ch in sp.attached:
                break
            if ch in sp.valued:
                step = 1 if idx + 1 < len(v) else 2
                break
            if ch not in sp.flags:
                bail(words, j, res)
                return None
        j += step
    while sp.assigns and j < len(words) and ASSIGN_RE.match(words[j].value) and not words[j].quoted:
        j += 1
    j += sp.positional
    if name == "flock" and j + 1 < len(words) and words[j].value in ("-c", "--command"):
        run_body(words[j + 1], s, base, can_rewrite, res, depth)
        return None
    return j if j < len(words) else None


def runner(words, i, s, base, res, depth):
    """docker, podman, ssh, wsl: a `cargo test` among the words, or inside a quoted word, must carry its cap."""
    rest = words[i + 1 :]
    for k, w in enumerate(rest):
        if not w.dyn and w.value.rsplit("/", 1)[-1] == "cargo":
            tail = [x.value for x in rest[k + 1 :]]
            lead = [x.value for x in rest[:k]]
            if tail[:1] and tail[0].startswith("+"):
                tail = tail[1:]
            if tail[:1] and tail[0] in ("test", "t", "nextest"):
                res.compile = True
                carries = (any(t.startswith(("--test-threads", "--jobs")) or t in ("--no-run", "-j") for t in tail)
                           or any(re.match(r"(RUST_TEST_THREADS|NEXTEST_TEST_THREADS)=[1-9]", t) for t in lead))
                res.unknown = res.unknown or not carries
        if " " in w.value or "\n" in w.value:
            analyze(w.value, base, False, res, depth + 1)


def command(words, s, base, can_rewrite, res, depth):
    last_end = words[-1].end
    env = {}
    i = 0
    while i < len(words):
        w = words[i]
        if not w.quoted and not w.dyn and w.value in RESERVED:
            i += 1
        elif ASSIGN_RE.match(s[w.start : w.end]):
            name, _, val = w.value.partition("=")
            env[name] = None if w.dyn else val
            i += 1
        else:
            break
    while i is not None and i < len(words):
        w = words[i]
        if w.dyn:
            if any(not x.dyn and x.value in ("test", "t", "nextest") for x in words[i + 1 :]):
                res.compile = res.unknown = True
            return
        name = w.value.rsplit("/", 1)[-1]
        if name == "cargo":
            cargo(words, i, env, last_end, base, can_rewrite, res)
            return
        if name == "env":
            i = skip_env(words, i + 1, env, res)
        elif name in WRAPPERS:
            i = skip_wrapper(name, words, i, res)
        elif name in EXEC_WRAPPERS:
            i = skip_exec_wrapper(name, words, i, env, s, base, can_rewrite, res, depth)
        elif name in RUNNERS:
            runner(words, i, s, base, res, depth)
            return
        elif name in SHELLS:
            shell_body(words, i, s, base, can_rewrite, res, depth)
            return
        elif name == "eval":
            eval_body(words, i, s, base, can_rewrite, res, depth)
            return
        else:
            return


def run_body(word, s, base, can_rewrite, res, depth):
    if word.single_plain_quote():
        analyze(word.value, base + word.start + 1, can_rewrite, res, depth + 1)
    else:
        analyze(word.value, base, False, res, depth + 1)


def shell_body(words, i, s, base, can_rewrite, res, depth):
    j, has_c = i + 1, False
    while j < len(words):
        v = words[j].value
        if v == "--":
            j += 1
            break
        if not v or v[0] not in "-+" or v in ("-", "+"):
            break
        if re.fullmatch(r"-[A-Za-z]+", v) and "c" in v:
            has_c = True
        if v in ("-o", "-O", "+o", "+O", "--rcfile", "--init-file"):
            j += 1
        j += 1
    if has_c and j < len(words):
        run_body(words[j], s, base, can_rewrite, res, depth)


def eval_body(words, i, s, base, can_rewrite, res, depth):
    args = words[i + 1 :]
    if args and args[0].value == "--":
        args = args[1:]
    if len(args) == 1:
        run_body(args[0], s, base, can_rewrite, res, depth)
    elif args:
        analyze(" ".join(a.value for a in args), base, False, res, depth + 1)


def cargo(words, i, env, last_end, base, can_rewrite, res):
    args = words[i + 1 :]
    j = 0
    if j < len(args) and not args[j].dyn and args[j].value.startswith("+"):
        j += 1
    while j < len(args) and not args[j].dyn and args[j].value.startswith("-"):
        v = args[j].value
        if v in CARGO_VALUE_GLOBALS:
            j += 2
        elif v in CARGO_FLAG_GLOBALS or v.startswith(("--color=", "--config=", "--explain=", "-Z", "-C")):
            j += 1
        else:
            res.compile = res.unknown = True  # a cargo option this file cannot parse hides the subcommand
            return
    if j >= len(args):
        return
    sub = args[j]
    if sub.dyn:
        res.compile = res.unknown = True
        return
    v = sub.value
    if v not in COMPILING:
        return
    res.compile = True
    if v in ("test", "t"):
        nextest = False
    elif v == "nextest":
        nxt = args[j + 1] if j + 1 < len(args) else None
        if nxt is None or nxt.dyn:
            return
        if nxt.value.startswith("-"):
            res.unknown = True
            return
        if nxt.value not in ("run", "r"):
            return
        j, nextest = j + 1, True
    else:
        return
    rest = args[j + 1 :]
    dash = next((k for k, w in enumerate(rest) if not w.dyn and w.value == "--"), None)
    before = rest if dash is None else rest[:dash]
    after = [] if dash is None else rest[dash + 1 :]
    if any(w.value == "--no-run" for w in before):
        return
    if nextest:
        if valid_threads(env.get("NEXTEST_TEST_THREADS")):
            return
        if any(w.value in ("--test-threads", "--jobs", "-j") or w.value.startswith(("--test-threads=", "--jobs="))
               or NEXTEST_J_RE.match(w.value) for w in before):
            return
    else:
        if valid_threads(env.get("RUST_TEST_THREADS")):
            return
        if any(w.value.startswith("--test-threads") for w in after):
            return
    if not can_rewrite or any(w.substs for w in rest):
        res.unknown = True
        return
    text = f" {CAP}"
    if nextest:
        before_dash = (rest[dash - 1] if dash else args[j]) if dash is not None else None
        pos = last_end if before_dash is None else before_dash.end
    elif dash is not None:
        pos = rest[dash].end
    else:
        pos, text = last_end, f" -- {CAP}"
    res.edits.append((base + pos, text))


def apply(cmd):
    res = Result()
    analyze(cmd, 0, True, res)
    return res


def rewrite(cmd):
    res = apply(cmd)
    if res.unknown:
        return None
    for at, text in sorted(set(res.edits), reverse=True):
        cmd = cmd[:at] + text + cmd[at:]
    return cmd


def main(argv):
    if len(argv) == 3 and argv[1] == "--check":
        res = apply(argv[2])
        print(f"{int(res.compile)} {'fail' if res.unknown else 'ok'}")
        return 0
    if len(argv) != 2:
        print("usage: cargo_test_cap.py [--check] COMMAND", file=sys.stderr)
        return 2
    out = rewrite(argv[1])
    if out is None:
        return 1
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
