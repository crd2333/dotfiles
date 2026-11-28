#!/usr/bin/env python3
"""Find and reattach stranded Pi/agy terminals on Linux."""

import argparse
import os
import sys
from dataclasses import dataclass
from pathlib import Path

if sys.platform == "linux":
    import ctypes
    import errno
    import fcntl
    import pwd
    import select
    import signal
    import stat
    import termios
    import tty

PROC = Path("/proc")
AGENTS = {"pi", "agy"}
SHELLS = {"bash", "zsh", "sh", "dash", "fish", "ksh", "tcsh", "csh"}


@dataclass(frozen=True)
class Process:
    pid: int
    name: str
    parent: int
    session: int
    controlling_tty: int
    start: int


@dataclass(frozen=True)
class Holder:
    process: Process
    fd: int


@dataclass
class Terminal:
    agent: Process
    pty: tuple[int, int] | None  # devpts filesystem device, PTY index
    session: int                 # Original terminal session leader (usually the shell)
    wrapper: Process | None
    holders: list[Holder]
    reason: str


def read_process(pid, uid):
    path = PROC / str(pid)
    if path.stat().st_uid != uid:
        return None
    line = (path / "stat").read_text(errors="replace")
    left, right = line.rsplit(")", 1)
    fields = right.split()
    if fields[0] in ("Z", "X"):
        return None
    return Process(pid, left.split("(", 1)[1], int(fields[1]), int(fields[3]),
                   int(fields[4]), int(fields[19]))


def slave_key(pid):
    path = PROC / str(pid) / "fd/0"
    try:
        info = path.stat()
    except OSError:
        return None
    major = os.major(info.st_rdev)
    if stat.S_ISCHR(info.st_mode) and 136 <= major <= 143:
        return info.st_dev, (major - 136) * 256 + os.minor(info.st_rdev)
    return None


def master_key(pid, fd):
    base = PROC / str(pid)
    path = base / "fd" / str(fd)
    try:
        target = path.readlink()
        if target.name != "ptmx":
            return None
        # A legacy /dev/ptmx node lives on devtmpfs, not on the devpts mount.
        device = (base / "root/dev/pts").stat().st_dev if target == Path("/dev/ptmx") else path.stat().st_dev
        with (base / "fdinfo" / str(fd)).open() as stream:
            for line in stream:
                if line.startswith("tty-index:"):
                    return device, int(line.split()[1])
    except OSError:
        pass
    return None


def ancestors(process, processes):
    while (process := processes.get(process.parent)) is not None:
        yield process


def manager(holder, pty):
    process = holder.process
    if process.pid == os.getpid():
        return ""  # The FD was inherited by this invocation.
    if master_key(process.pid, 0) == pty:
        return process.name  # This master is also the process's standard input.
    if process.name.removeprefix("-") in SHELLS and holder.fd > 2:
        return ""  # A shell can inherit an idle duplicate from VS Code's pty host.
    try:
        args = (PROC / str(process.pid) / "cmdline").read_bytes().split(b"\0")
    except OSError:
        args = []
    if b"--type=ptyHost" in args:
        return "VS Code"
    if process.name.startswith(("tmux", "screen", "SCREEN", "sshd")):
        return process.name
    if (process.name.startswith("python") and holder.fd > 2 and len(args) > 1
            and args[1].endswith(b"/coding-agent-terminal.py")):
        return ""  # The link wrapper only relays its child's stdout to its own terminal.
    return process.name  # Do not compete with an unfamiliar PTY owner.


def discover(uid):
    processes = {}
    for path in PROC.iterdir():
        if path.name.isdecimal():
            try:
                process = read_process(int(path.name), uid)
            except OSError:  # The process exited, or /proc access is restricted.
                continue
            if process:
                processes[process.pid] = process
    agents = [p for p in processes.values() if p.name in AGENTS]
    agent_ptys = {p.pid: slave_key(p.pid) for p in agents}
    relays = {p.pid: [q for q in ancestors(p, processes) if q.name == "script"] for p in agents}
    outer_ptys = {q.pid: slave_key(q.pid) for wrappers in relays.values() for q in wrappers}
    masters = {pty: [] for pty in set(agent_ptys.values()) | set(outer_ptys.values()) if pty}
    if masters:
        for process in processes.values():
            try:
                for path in (PROC / str(process.pid) / "fd").iterdir():
                    key = master_key(process.pid, path.name)
                    if key in masters:
                        masters[key].append(Holder(process, int(path.name)))
            except OSError:
                continue
    terminals = {}
    for agent in sorted(agents, key=lambda p: p.pid):
        pty, session, wrapper = agent_ptys[agent.pid], agent.session, None
        for relay in relays[agent.pid]:
            outer = outer_ptys[relay.pid]
            if outer and outer != pty and any(h.process == relay for h in masters.get(pty, ())):
                pty, session, wrapper = outer, relay.session, relay
        holders = masters.get(pty, [])
        owners = sorted({name for h in holders if (name := manager(h, pty))})
        reason = ("no PTY on stdin" if not pty else
                  "no accessible PTY master" if not holders else
                  "managed by " + ", ".join(owners) if owners else "")
        terminals[agent.pid] = Terminal(agent, pty, session, wrapper, holders, reason)
    return terminals


def duplicate_fd(pid, fd):
    if pid == os.getpid():
        return os.dup(fd)
    try:
        getfd = ctypes.CDLL("libc.so.6", use_errno=True).pidfd_getfd
        pidfd = os.pidfd_open(pid)
    except AttributeError:
        raise RuntimeError("PID FD transfer requires Linux 5.6+ and Python/libc pidfd support") from None
    getfd.argtypes = (ctypes.c_int, ctypes.c_int, ctypes.c_uint)
    getfd.restype = ctypes.c_int
    try:
        result = getfd(pidfd, fd, 0)
        if result < 0:
            error = ctypes.get_errno()
            raise OSError(error, os.strerror(error))
        return result
    finally:
        os.close(pidfd)


def is_peer(master, pid):
    # Verify the actual slave even if the original holder used a different mount namespace.
    peer = fcntl.ioctl(master, getattr(termios, "TIOCGPTPEER", 0x5441),
                       os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        return os.path.samestat(os.fstat(peer), (PROC / str(pid) / "fd/0").stat())
    finally:
        os.close(peer)


def acquire(terminal, uid):
    if terminal.reason:
        raise RuntimeError(terminal.reason)
    candidates = sorted(terminal.holders, key=lambda h: h.process.pid != os.getpid())
    denied = False
    unsupported = False
    for holder in candidates:
        pid = holder.process.pid
        try:
            if read_process(pid, uid) != holder.process:
                continue
            fd = duplicate_fd(pid, holder.fd)
        except OSError as error:
            denied |= error.errno in (errno.EPERM, errno.EACCES)
            unsupported |= error.errno in (errno.ENOSYS, errno.EINVAL)
            continue
        try:
            current = terminal.wrapper or terminal.agent
            if (read_process(pid, uid) == holder.process
                    and read_process(terminal.agent.pid, uid) == terminal.agent
                    and read_process(current.pid, uid) == current
                    and is_peer(fd, current.pid)):
                return fd
        except OSError:
            pass
        os.close(fd)
    if denied:
        raise PermissionError("kernel denied access to the PTY master")
    if unsupported:
        raise RuntimeError("this kernel does not support pidfd_getfd")
    raise RuntimeError("PTY changed or is no longer available; run --list again")


def attach(master, wrapper):
    saved = termios.tcgetattr(0)
    pending = b""
    detaching = False

    def resize(*_):
        termios.tcsetwinsize(master, termios.tcgetwinsize(0))
        if wrapper and not wrapper.controlling_tty:
            # An orphaned script(1) relay no longer gets SIGWINCH from the kernel.
            try:
                os.kill(wrapper.pid, signal.SIGWINCH)
            except ProcessLookupError:
                pass

    def leave(*_):
        raise SystemExit(0)

    for sig in (signal.SIGHUP, signal.SIGTERM):
        signal.signal(sig, leave)
    signal.signal(signal.SIGWINCH, resize)
    try:
        tty.setraw(0)
        resize()
        while not detaching or pending:
            readers, writers, _ = select.select(
                [master] if detaching or pending else [0, master], [master] if pending else [], []
            )
            if 0 in readers:
                data = os.read(0, 4096)
                pending, detach_key, _ = data.partition(b"\x1d")  # Ctrl-]
                detaching = bool(detach_key) or not data
            if writers:
                try:
                    pending = pending[os.write(master, pending):]
                except BlockingIOError:
                    pass
            if master in readers:
                try:
                    data = os.read(master, 65536)
                except BlockingIOError:
                    continue
                if not data:
                    return
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
    except OSError as error:
        if error.errno != errno.EIO:  # An exited agent can leave a closed PTY slave.
            raise
    finally:
        try:
            termios.tcsetattr(0, termios.TCSANOW, saved)
        except termios.error:
            pass  # The new terminal may already have hung up.


def show(terminals):
    print(f"{len(terminals)} Pi/agy processes")
    print(f"{'PID':>8}  {'AGENT':5}  {'PTY':8}  {'SID':>8}  {'STATUS':43}  CWD")
    for terminal in terminals.values():
        agent = terminal.agent
        status = terminal.reason or "recovery candidate"
        try:
            cwd = str((PROC / str(agent.pid) / "cwd").readlink())
        except OSError:
            cwd = "?"
        pty = f"pts/{terminal.pty[1]}" if terminal.pty else "-"
        print(f"{agent.pid:8}  {agent.name:5}  {pty:8}  {terminal.session:8}  {status:43}  {cwd}")


def main():
    parser = argparse.ArgumentParser(prog="recover-terminal", description=__doc__)
    parser.add_argument("target", nargs="?", default="list", metavar="list|PID",
                        help="list live Pi/agy processes (default) or reattach to PID; Ctrl-] detaches")
    target = parser.parse_args().target
    try:
        pid = None if target == "list" else int(target)
    except ValueError:
        parser.error("expected 'list' or a numeric PID")
    if sys.platform != "linux":
        parser.error("live process recovery requires Linux")
    uid = os.getuid()
    if uid == 0:
        uid = int(os.environ.get("SUDO_UID", uid))
    terminals = discover(uid)
    if pid is None:
        show(terminals)
        return
    if pid not in terminals:
        parser.error("PID is not a live Pi/agy process belonging to your user; run 'recover-terminal list'")
    if not (os.isatty(0) and os.isatty(1)):
        parser.error("run the recovery from an interactive terminal")
    terminal = terminals[pid]
    account = pwd.getpwuid(uid)
    try:
        fd = acquire(terminal, uid)
    except PermissionError as error:
        if os.geteuid() == 0:
            raise
        # Use an absolute path so sudo does not need to find the helper on PATH.
        try:
            os.execlp("sudo", "sudo", "--", str(Path(__file__).resolve()), str(pid))
        except FileNotFoundError:
            raise RuntimeError(f"{error}; sudo is not available") from None
    try:
        if os.geteuid() == 0 and uid != 0:
            os.initgroups(account.pw_name, account.pw_gid)
            os.setgid(account.pw_gid)
            os.setuid(uid)
        if slave_key(os.getpid()) == terminal.pty:
            raise RuntimeError("open a separate terminal for the recovery")
        locks = Path(account.pw_dir) / ".cache/vscode-terminal-recovery"
        locks.mkdir(mode=0o700, parents=True, exist_ok=True)
        device, index = terminal.pty
        with (locks / f"{device}-{index}").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError("this PTY already has an active recovery connection") from None
            print(f"Attached to {terminal.agent.name} (PID {pid}, pts/{index}). Ctrl-] to detach.", flush=True)
            attach(fd, terminal.wrapper)
            print("\nDetached.", flush=True)
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        sys.exit(str(error))
