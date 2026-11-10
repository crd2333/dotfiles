import errno
import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time
import unittest
import fcntl
from urllib.parse import quote_from_bytes

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "zsh/lib/coding-agent-terminal.py"
spec = importlib.util.spec_from_file_location("coding_agent_terminal", WRAPPER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def link(target, end=b"\x1b\\", params=b""):
    return b"\x1b]8;" + params + b";" + target + end + "鹿与建筑".encode() + b"\x1b]8;;" + end


class Terminal:
    """Run a command in its own controlling terminal, never the user's terminal."""

    def __init__(self, argv, env):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvpe(argv[0], argv, env)
        self.original = termios.tcgetattr(self.fd)
        self.resize(24, 80)
        self.output = b""
        self.status = None

    def resize(self, rows, cols):
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

    def read_until(self, marker=None):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if marker is not None and marker in self.output:
                return self.output
            if not select.select([self.fd], [], [], 0.1)[0]:
                continue
            try:
                data = os.read(self.fd, 65536)
            except OSError as exc:
                if exc.errno != errno.EIO:
                    raise
                data = b""
            if not data:
                if marker is not None:
                    raise AssertionError(f"Missing {marker!r}: {self.output!r}")
                _, self.status = os.waitpid(self.pid, 0)
                return self.output
            self.output += data
        raise AssertionError(f"Terminal timed out: {self.output!r}")

    def close(self):
        if self.status is None:
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(self.pid, 0)
        os.close(self.fd)


class LinkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.file = Path(self.temp.name) / "鹿 # ? % image.png"
        self.file.touch()
        self.path = os.fsencode(self.file)
        self.uri = b"vscode://vscode-remote/ssh-remote+yq31" + quote_from_bytes(self.path, safe="/").encode()

    def rewrite(self, chunks):
        rewriter = module.LinkRewriter("yq31")
        return b"".join(rewriter.feed(chunk) for chunk in chunks) + rewriter.finish()

    def test_both_terminators_params_and_every_chunk_boundary(self):
        for end in (b"\x07", b"\x1b\\"):
            source = b"\x1b[32m" + link(self.path, end, b"id=42") + b"\x1b[0m"
            expected = b"\x1b[32m" + link(self.uri + b":1", end, b"id=42") + b"\x1b[0m"
            for split in range(len(source) + 1):
                self.assertEqual(self.rewrite([source[:split], source[split:]]), expected)
            self.assertEqual(self.rewrite([bytes([c]) for c in source]), expected)

    def test_existing_line_and_column(self):
        for suffix in (b":42", b":42:7"):
            self.assertEqual(self.rewrite([link(self.path + suffix)]), link(self.uri + suffix))

    def test_extensionless_file(self):
        path = Path(self.temp.name) / "LICENSE"
        path.touch()
        self.assertTrue(module.LinkRewriter("yq31").target(os.fsencode(path)).endswith(b"/LICENSE:1"))

    def test_relative_files_and_locations_resolve_against_agent_directory(self):
        for relative, base in (
            (os.fsencode(self.file.name), self.temp.name),
            (b"./" + os.fsencode(self.file.name), self.temp.name),
            (b"../" + os.fsencode(self.file.name), str(Path(self.temp.name) / "subdir")),
        ):
            for suffix in (b"", b":42", b":42:7"):
                rewriter = module.LinkRewriter("yq31", cwd=base)
                source = link(relative + suffix)
                result = b"".join(rewriter.feed(bytes([c])) for c in source) + rewriter.finish()
                self.assertEqual(result, link(self.uri + (suffix or b":1")))

    def test_relative_directory_and_missing_file_are_preserved(self):
        rewriter = module.LinkRewriter("yq31", cwd=Path(self.temp.name).parent)
        self.assertEqual(rewriter.target(os.fsencode(Path(self.temp.name).name)),
                         os.fsencode(Path(self.temp.name).name))
        self.assertEqual(rewriter.target(b"missing.png"), b"missing.png")

    def test_explicit_uri_is_not_rewritten_even_if_matching_file_exists(self):
        directory = Path(self.temp.name) / "https:"
        directory.mkdir()
        (directory / "example.com").touch()
        rewriter = module.LinkRewriter("yq31", cwd=self.temp.name)
        self.assertEqual(rewriter.target(b"https://example.com"), b"https://example.com")

    def test_other_targets_remain_identical(self):
        for target in (b"https://example.com/a?q=1", b"file:///tmp/a", b"relative/a.png",
                       b"//example.com/a", os.fsencode(self.temp.name), b"/missing/file", b""):
            source = link(target)
            self.assertEqual(self.rewrite([bytes([c]) for c in source]), source)

    def test_other_terminal_strings_are_opaque(self):
        for prefix, end in ((b"\x1b]1337;", b"\x07"), (b"\x1bP", b"\x1b\\"),
                            (b"\x1b_G", b"\x1b\\"), (b"\x1b^", b"\x1b\\")):
            source = prefix + link(self.path, b"\x07") + end
            self.assertEqual(self.rewrite([bytes([c]) for c in source]), source)

    def test_incomplete_and_oversized_sequences_are_preserved(self):
        for source in (b"text\x1b", b"text\x1b]8;id;/tmp/a", b"\x1b]8;;" + b"x" * 70000):
            self.assertEqual(self.rewrite([source]), source)

    def test_ordinary_output_and_terminal_queries_are_not_delayed(self):
        rewriter = module.LinkRewriter("yq31")
        for data in ("正常输出".encode(), b"\x1b[6n", b"\x1b[?1049h", b"\x1b[31mRED\x1b[0m"):
            self.assertEqual(rewriter.feed(data), data)

    def test_pty_exit_code_and_shell_quoting(self):
        argument = "空格 ; $(echo injected) " + chr(39) + chr(34)
        terminal = Terminal(
            [sys.executable, str(WRAPPER), sys.executable, "-c",
             "import os,sys; os.write(1,sys.argv[1].encode()); sys.exit(7)", argument],
            dict(os.environ, VSCODE_SSH_HOST="yq31"),
        )
        self.addCleanup(terminal.close)
        self.assertEqual(terminal.read_until(), argument.encode())
        self.assertEqual(os.waitstatus_to_exitcode(terminal.status), 7)
        self.assertEqual(termios.tcgetattr(terminal.fd), terminal.original)

    def test_termination_restores_terminal(self):
        terminal = Terminal(
            [sys.executable, str(WRAPPER), sys.executable, "-u", "-c",
             "import time; print('READY'); time.sleep(60)"],
            dict(os.environ, VSCODE_SSH_HOST="yq31"),
        )
        self.addCleanup(terminal.close)
        terminal.read_until(b"READY")
        os.kill(terminal.pid, signal.SIGTERM)
        terminal.read_until()
        self.assertEqual(os.waitstatus_to_exitcode(terminal.status), 128 + signal.SIGTERM)
        self.assertEqual(termios.tcgetattr(terminal.fd), terminal.original)

    def test_pty_input_resize_interrupt_exit_and_restoration(self):
        code = r'''
import os, signal, sys, tty
tty.setcbreak(0)
def size(*_):
    s = os.get_terminal_size()
    print(f"SIZE:{s.lines}x{s.columns}", flush=True)
def interrupt(*_):
    print("INTERRUPTED", flush=True)
    sys.exit(23)
signal.signal(signal.SIGWINCH, size)
signal.signal(signal.SIGINT, interrupt)
sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))
sys.stdout.buffer.flush()
print("TTY:" + str(all(os.isatty(fd) for fd in (0, 1, 2))), flush=True)
size()
while True:
    print("INPUT:" + os.read(0, 3).hex(), flush=True)
'''
        env = dict(os.environ, VSCODE_SSH_HOST="yq31")
        terminal = Terminal([sys.executable, str(WRAPPER), sys.executable, "-u", "-c", code,
                             link(self.path).hex()], env)
        self.addCleanup(terminal.close)
        terminal.read_until(b"SIZE:24x80")
        self.assertIn(b"TTY:True", terminal.output)
        self.assertIn(link(self.uri + b":1"), terminal.output)
        terminal.resize(42, 101)
        terminal.read_until(b"SIZE:42x101")
        os.write(terminal.fd, b"\x1b[A")
        terminal.read_until(b"INPUT:1b5b41")
        os.write(terminal.fd, b"\x03")
        terminal.read_until()
        self.assertIn(b"INTERRUPTED", terminal.output)
        self.assertEqual(os.waitstatus_to_exitcode(terminal.status), 23)
        self.assertEqual(termios.tcgetattr(terminal.fd), terminal.original)


class ShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.bin = Path(self.temp.name)
        rc = (ROOT / "zsh/.zshrc").read_text()
        self.functions = rc.split("# ===== Coding Agents with Proxy Support =====", 1)[1].split("# Tokdash", 1)[0]
        for name in ("pi", "claude", "codex", "opencode", "python3"):
            path = self.bin / name
            path.write_text("#!/bin/sh\nexec /usr/bin/python3 -c 'import json,os,sys; print(json.dumps([os.path.basename(sys.argv[1]), sys.argv[2:], os.getenv(\"TEST_PROXY\")]))' \"$0\" \"$@\"\n")
            path.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + ":/usr/bin:/bin", TERM_PROGRAM="vscode",
                        VSCODE_SSH_HOST="yq31", ZSH=str(ROOT / "zsh"))

    def run_shell(self, command, tty=False, **env):
        code = self.functions + '\nsystem_proxy() { export TEST_PROXY=on; }; unset_proxy() { export TEST_PROXY=off; };\n' + command
        args = ["/usr/bin/zsh", "-f", "-c", code]
        environment = dict(self.env, **env)
        if tty:
            terminal = Terminal(args, environment)
            try:
                output = terminal.read_until().decode()
                self.assertEqual(os.waitstatus_to_exitcode(terminal.status), 0)
            finally:
                terminal.close()
        else:
            output = subprocess.check_output(args, env=environment, text=True)
        return json.loads(next(line for line in reversed(output.splitlines()) if line.startswith("[")))

    def test_interactive_launch_and_argument_preservation(self):
        for command in ("pi", "claude", "codex", "opencode"):
            result = self.run_shell(command + " 'a b' 'quote\"value'", tty=True)
            self.assertEqual(result[:2], ["python3", [str(WRAPPER), command, "a b", 'quote"value']])

    def test_bypass_without_tty_vscode_or_host(self):
        self.assertEqual(self.run_shell("pi 'a b'")[:2], ["pi", ["a b"]])
        for env in ({"TERM_PROGRAM": "other"}, {"VSCODE_SSH_HOST": ""}):
            self.assertEqual(self.run_shell("pi", tty=True, **env)[0], "pi")
        for command in ("pi | cat", "pi 2>/dev/null"):
            self.assertEqual(self.run_shell(command, tty=True)[0], "pi")

    def test_noninteractive_modes_bypass(self):
        for command in ("pi --mode rpc", "pi --mode=json", "pi -p test", "claude --print test",
                        "claude --output-format=json", "codex exec test", "codex review", "opencode run test"):
            self.assertEqual(self.run_shell(command, tty=True)[0], command.split()[0])
        # Codex -p means profile, not print mode.
        self.assertEqual(self.run_shell("codex -p work", tty=True)[0], "python3")

    def test_proxy_branches_and_no_proxy_flag_removal(self):
        for command, proxy, args in (("codex --no-proxy exec test", "off", ["exec", "test"]),
                                     ("opencode --no_proxy run test", "off", ["run", "test"]),
                                     ("codex --help", None, ["--help"]),
                                     ("opencode models", None, ["models"]),
                                     ("codex exec test", "on", ["exec", "test"])):
            result = self.run_shell(command)
            self.assertEqual(result[1:], [args, proxy])
        result = self.run_shell("codex --no-proxy 'a b'", tty=True)
        self.assertEqual(result[0], "python3")
        self.assertEqual(result[1], [str(WRAPPER), "codex", "a b"])
        self.assertEqual(result[2], "off")


if __name__ == "__main__":
    unittest.main()
