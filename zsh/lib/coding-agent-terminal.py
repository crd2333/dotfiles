#!/usr/bin/env python3
"""Make bare OSC 8 file links clickable in a VSCode Remote-SSH terminal."""

import os
import re
import shlex
import signal
import subprocess
import sys
from urllib.parse import quote, quote_from_bytes

OSC8 = b"\x1b]8;"
OSC_END = re.compile(rb"\x07|\x1b\\")
ST = re.compile(rb"\x1b\\")
LOCATION = re.compile(rb":\d+(?::\d+)?$")
SCHEME = re.compile(rb"^[a-zA-Z][a-zA-Z0-9+.-]*:")


class LinkRewriter:
    def __init__(self, host, cwd=None):
        self.base = ("vscode://vscode-remote/ssh-remote+" + quote(host, safe="")).encode()
        self.cwd = os.fsencode(cwd) if cwd is not None else os.getcwdb()
        self.pending = b""
        self.string_end = None

    def target(self, target):
        if target.startswith(b"//"):
            return target
        location = LOCATION.search(target)
        path = target[:location.start()] if location else target
        if not path or SCHEME.match(path):
            return target
        # Relative Markdown links use the same starting directory as the agent.
        path = os.path.abspath(os.path.join(self.cwd, path))
        if not os.path.isfile(path):
            return target
        suffix = location.group() if location else b":1"
        return self.base + quote_from_bytes(path, safe="/").encode() + suffix

    def feed(self, data):
        self.pending += data
        output = bytearray()
        while self.pending:
            # Pass other OSC/DCS/APC strings through without buffering their payloads.
            if self.string_end is not None:
                end = self.string_end.search(self.pending)
                if end:
                    output.extend(self.pending[:end.end()])
                    self.pending = self.pending[end.end():]
                    self.string_end = None
                    continue
                keep = 1 if self.pending.endswith(b"\x1b") else 0
                size = len(self.pending) - keep
                output.extend(self.pending[:size])
                self.pending = self.pending[size:]
                break

            start = self.pending.find(b"\x1b")
            if start < 0:
                output.extend(self.pending)
                self.pending = b""
                break
            output.extend(self.pending[:start])
            self.pending = self.pending[start:]
            if len(self.pending) < 2:
                break
            if self.pending[1] not in b"]P_^X":
                output.append(self.pending[0])
                self.pending = self.pending[1:]
                continue
            if self.pending.startswith(b"\x1b]"):
                if len(self.pending) < len(OSC8) and OSC8.startswith(self.pending):
                    break
                if self.pending.startswith(OSC8):
                    end = OSC_END.search(self.pending, len(OSC8))
                    if end:
                        params, separator, target = self.pending[len(OSC8):end.start()].partition(b";")
                        output.extend(OSC8 + params + separator)
                        output.extend(self.target(target) if separator else target)
                        output.extend(self.pending[end.start():end.end()])
                        self.pending = self.pending[end.end():]
                        continue
                    if len(self.pending) <= 65536:
                        break
                self.string_end = OSC_END
            else:
                self.string_end = ST
            output.extend(self.pending[:2])
            self.pending = self.pending[2:]
        return bytes(output)

    def finish(self):
        pending, self.pending = self.pending, b""
        return pending


def main():
    rewriter = LinkRewriter(os.environ["VSCODE_SSH_HOST"])
    # script handles raw input, signals, window resizing and terminal restoration.
    command = "exec " + shlex.join(sys.argv[1:])
    with subprocess.Popen(
        ["script", "-qefc", command, "/dev/null"], stdout=subprocess.PIPE
    ) as child:
        termination_signal = 0

        def forward_signal(number, _):
            nonlocal termination_signal
            termination_signal = number
            child.send_signal(number)

        for sig in (signal.SIGHUP, signal.SIGTERM):
            signal.signal(sig, forward_signal)
        try:
            while data := os.read(child.stdout.fileno(), 65536):
                sys.stdout.buffer.write(rewriter.feed(data))
                sys.stdout.buffer.flush()
            sys.stdout.buffer.write(rewriter.finish())
            sys.stdout.buffer.flush()
            status = child.wait()
            return 128 + termination_signal if termination_signal else status
        finally:
            if child.poll() is None:
                child.terminate()


if __name__ == "__main__":
    sys.exit(main())
