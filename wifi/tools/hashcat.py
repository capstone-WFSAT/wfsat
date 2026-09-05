#!/usr/bin/env python
# -*- coding: utf-8 -*-

from .dependency import Dependency
from ..config import Configuration
from ..util.process import Process
from ..util.color import Color
from ..util.logger import log_debug, log_info, log_warning, log_error
import os
import re
import threading
class HashcatCracker:
    """
    Hashcat process wrapper.

    - Runs hashcat with machine-readable status.
    - Captures stdout and stderr separately.
    - Detects backend/device initialization failures.
    - Keeps the last hashcat result.
    """

    STATUS_TIMER_SECONDS = 2

    def __init__(self, hash_file, wordlist, mode='22000',
                 target_is_wpa3_sae=False):
        self.hash_file = hash_file
        self.wordlist = wordlist
        self.mode = mode
        self.target_is_wpa3_sae = target_is_wpa3_sae

        self.proc = None
        self._result_key = None

        self._status = {
            'progress': 0.0,
            'speed': 'Unknown',
            'eta': 'Unknown'
        }

        self._status_lock = threading.Lock()
        self._reader_thread = None
        self._stop_reader = threading.Event()

        self.stdout_lines = []
        self.stderr_lines = []

        self.backend_error = False
        self.returncode = None

    def start(self, show_command=False):
        """
        Launch hashcat.

        We intentionally do not use --quiet because machine-readable
        STATUS output is required for progress reporting.
        """

        command = [
            'hashcat',
            '-m', str(self.mode),

            '--status',
            '--status-timer', str(self.STATUS_TIMER_SECONDS),
            '--machine-readable',

            # Lower workload is more stable on CPU/OpenCL environments.
            '-w', '2',

            self.hash_file,
            self.wordlist
        ]

        # On systems where hashcat reports an unstable/no device,
        # --force may be necessary.
        if Hashcat.should_use_force():
            command.append('--force')

        if show_command:
            Color.pl(
                '{+} {D}Running: {W}{P}%s{W}' %
                ' '.join(command)
            )

        self.proc = Process(command)

        self._reader_thread = threading.Thread(
            target=self._read_output,
            daemon=True
        )

        self._reader_thread.start()

        return self.proc

    def _read_output(self):
        """
        Read both stdout and stderr.

        Hashcat sends some backend/device errors to stderr, so reading
        stdout only is insufficient.
        """

        if not self.proc or not self.proc.pid:
            return

        stdout = getattr(self.proc.pid, 'stdout', None)
        stderr = getattr(self.proc.pid, 'stderr', None)

        if not stdout:
            return

        try:
            # stdout is consumed in this thread.
            while not self._stop_reader.is_set():

                raw = stdout.readline()

                if raw:
                    line = (
                        raw.decode('utf-8', errors='replace')
                        if isinstance(raw, bytes)
                        else raw
                    )

                    line = line.rstrip('\r\n')

                    if line:
                        self.stdout_lines.append(line)
                        self._parse_stdout_line(line)

                else:
                    if self.proc.poll() is not None:
                        break

                    time.sleep(0.01)

            # Drain stderr after the process exits.
            if stderr:
                try:
                    remaining = stderr.read()

                    if remaining:
                        if isinstance(remaining, bytes):
                            remaining = remaining.decode(
                                'utf-8',
                                errors='replace'
                            )

                        for line in remaining.splitlines():
                            line = line.strip()

                            if line:
                                self.stderr_lines.append(line)
                                self._check_backend_error(line)

                except Exception as e:
                    log_debug(
                        'HashcatCracker',
                        f'Could not drain stderr: {e}'
                    )

        except Exception as e:
            log_debug(
                'HashcatCracker',
                f'Reader thread error: {e}'
            )

    def _parse_stdout_line(self, line):
        """
        Parse machine-readable stdout.
        """

        if line.startswith('STATUS\t'):
            self._parse_status_line(line)

        elif 'WPA*' in line and ':' in line:
            # hashcat --machine-readable output can still contain
            # cracked hash information.
            self._result_key = line.rsplit(':', 1)[-1].strip()

    def _check_backend_error(self, line):
        """
        Detect common hashcat backend initialization failures.
        """

        error_patterns = (
            'Not enough allocatable device memory',
            'Not enough free host memory',
            'No devices found',
            'No devices found/left',
            'CL_OUT_OF_HOST_MEMORY',
            'CL_OUT_OF_RESOURCES',
            'CL_MEM_OBJECT_ALLOCATION_FAILURE',
            'OpenCL API error',
            'Backend device initialization failed'
        )

        for pattern in error_patterns:
            if pattern.lower() in line.lower():
                self.backend_error = True

                log_error(
                    'HashcatCracker',
                    f'Hashcat backend error: {line}'
                )

                break

    def _parse_status_line(self, line):
        """
        Parse a hashcat --machine-readable STATUS line.
        """

        parts = line.split('\t')

        speed_hps = None
        progress_cur = None
        progress_total = None

        i = 0

        while i < len(parts):

            token = parts[i]

            if token == 'SPEED' and i + 1 < len(parts):
                try:
                    speed_hps = int(parts[i + 1])
                except (ValueError, TypeError):
                    pass

                i += 3

            elif token == 'PROGRESS' and i + 2 < len(parts):
                try:
                    progress_cur = int(parts[i + 1])
                    progress_total = int(parts[i + 2])
                except (ValueError, TypeError):
                    pass

                i += 3

            else:
                i += 1

        with self._status_lock:

            if (
                progress_total
                and progress_total > 0
                and progress_cur is not None
            ):
                self._status['progress'] = (
                    progress_cur / progress_total
                )

            if speed_hps is not None:
                self._status['speed'] = (
                    self._format_speed(speed_hps)
                )

            if (
                speed_hps
                and progress_total
                and progress_cur is not None
                and speed_hps > 0
                and progress_total > progress_cur
            ):
                remaining = (
                    progress_total - progress_cur
                ) / speed_hps

                self._status['eta'] = (
                    self._format_duration(remaining)
                )

    @staticmethod
    def _format_speed(hps):

        for unit, divisor in (
            ('GH/s', 1e9),
            ('MH/s', 1e6),
            ('kH/s', 1e3)
        ):
            if hps >= divisor:
                return f'{hps / divisor:.1f} {unit}'

        return f'{hps} H/s'

    @staticmethod
    def _format_duration(seconds):

        if seconds >= 3600:
            return f'{seconds / 3600:.1f}h'

        if seconds >= 60:
            return f'{seconds / 60:.1f}m'

        return f'{int(seconds)}s'

    def poll_status(self):
        with self._status_lock:
            return dict(self._status)

    def is_finished(self):

        if not self.proc:
            return True

        result = self.proc.poll()

        if result is not None:
            self.returncode = result

        return result is not None

    def get_result(self):

        if (
            self._reader_thread
            and self._reader_thread.is_alive()
        ):
            self._reader_thread.join(timeout=2.0)

        return self._result_key

    def get_errors(self):
        """
        Return stderr/backend errors collected from hashcat.
        """

        return '\n'.join(self.stderr_lines)

    def interrupt(self):

        self._stop_reader.set()

        if self.proc:
            self.proc.interrupt()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.interrupt()


class Hashcat(Dependency):

    dependency_required = False
    dependency_name = 'hashcat'
    dependency_url = 'https://hashcat.net/hashcat/'

    _cached_version = None

    @staticmethod
    def get_version():

        if Hashcat._cached_version is not None:
            return Hashcat._cached_version

        try:
            process = Process(
                ['hashcat', '--version']
            )

            stdout = process.stdout()

            match = re.search(
                r'v?(\d+)\.(\d+)\.(\d+)',
                stdout
            )

            if match:
                version = (
                    int(match.group(1)),
                    int(match.group(2)),
                    int(match.group(3))
                )

            else:
                match = re.search(
                    r'v?(\d+)\.(\d+)',
                    stdout
                )

                if match:
                    version = (
                        int(match.group(1)),
                        int(match.group(2)),
                        0
                    )
                else:
                    version = (0, 0, 0)

        except Exception as e:

            log_debug(
                'Hashcat',
                f'Failed to get hashcat version: {e}'
            )

            version = (0, 0, 0)

        Hashcat._cached_version = version

        log_debug(
            'Hashcat',
            'Hashcat version: %d.%d.%d' % version
        )

        return version

    @staticmethod
    def supports_mode_22000():

        version = Hashcat.get_version()

        if version == (0, 0, 0):
            log_warning(
                'Hashcat',
                'Could not determine hashcat version; '
                'assuming mode 22000 support'
            )

            return True

        supported = version >= (6, 0, 0)

        if not supported:
            log_warning(
                'Hashcat',
                'Hashcat %d.%d.%d does not support mode 22000'
                % version
            )

        return supported

    @staticmethod
    def should_use_force():

        try:
            command = [
                'hashcat',
                '-I'
            ]

            stderr = Process(command).stderr()

            return (
                'No devices found/left' in stderr
                or 'Unstable OpenCL driver detected!' in stderr
            )

        except Exception as e:

            log_debug(
                'Hashcat',
                f'Unable to check hashcat devices: {e}'
            )

            return False

    @staticmethod
    def _live_crack(
        hash_file,
        wordlist,
        mode='22000',
        show_command=False
    ):
        """
        Run hashcat and display live progress.

        Returns:
            password if cracked
            None otherwise
        """

        import time

        with HashcatCracker(
            hash_file,
            wordlist,
            mode=mode
        ) as cracker:

            cracker.start(
                show_command=show_command
            )

            try:

                while not cracker.is_finished():

                    status = cracker.poll_status()

                    Color.clear_entire_line()

                    Color.p(
                        '\r{+} {C}Cracking:{W} '
                        '%5.1f%%  '
                        '{C}Speed:{W} %s  '
                        '{C}ETA:{W} %s'
                        % (
                            status['progress'] * 100,
                            status['speed'],
                            status['eta']
                        )
                    )

                    time.sleep(
                        cracker.STATUS_TIMER_SECONDS
                    )

            except KeyboardInterrupt:

                Color.pl('')
                cracker.interrupt()
                raise

            Color.pl('')

            result = cracker.get_result()

            if result:
                return result

            # Important: hashcat may terminate before cracking because
            # the OpenCL backend cannot allocate enough memory.
            if cracker.backend_error:

                Color.pl(
                    '{!} {R}Hashcat backend initialization failed.{W}'
                )

                errors = cracker.get_errors()

                if errors:
                    log_error(
                        'Hashcat',
                        errors
                    )

                    if Configuration.verbose > 0:
                        Color.pl(
                            '{!} {O}%s{W}' % errors
                        )

            elif cracker.returncode not in (0, None):

                log_warning(
                    'Hashcat',
                    'Hashcat exited with return code %s'
                    % cracker.returncode
                )

            return None

    @staticmethod
    def _check_potfile(
        hash_file,
        mode='22000'
    ):
        """
        Check hashcat's potfile for an existing result.
        """

        command = [
            'hashcat',
            '--quiet',
            '-m', str(mode),
            hash_file,
            '--show'
        ]

        if Hashcat.should_use_force():
            command.append('--force')

        try:

            stdout, stderr = Process.call(
                command,
                timeout=30
            )

        except Exception as e:

            log_debug(
                'Hashcat',
                f'Potfile lookup failed: {e}'
            )

            return None

        if not stdout or ':' not in stdout:
            return None

        for line in stdout.strip().split('\n'):

            line = line.strip()

            if (
                'WPA*' in line
                and ':' in line
            ):
                return line.rsplit(
                    ':',
                    1
                )[-1].strip()

        return None

    @staticmethod
    def crack_handshake(
        handshake_obj,
        target_is_wpa3_sae,
        show_command=False,
        wordlist=None
    ):
        """
        Crack a WPA/WPA2/WPA3 capture using hashcat mode 22000.
        """

        hash_file = (
            HcxPcapngTool.generate_hash_file(
                handshake_obj,
                target_is_wpa3_sae,
                show_command=show_command
            )
        )

        if hash_file is None:

            Color.pl(
                '{!} {O}'
                'Falling back to aircrack-ng for cracking'
                '{W}'
            )

            from .aircrack import Aircrack

            return Aircrack.crack_handshake(
                handshake_obj,
                show_command=show_command,
                wordlist=wordlist
            )

        wordlist = (
            wordlist
            or Configuration.wordlist
        )

        try:

            hashcat_mode = '22000'

            file_type_msg = (
                'WPA3-SAE hash'
                if target_is_wpa3_sae
                else 'WPA/WPA2 hash'
            )

            if not Hashcat.supports_mode_22000():

                version = Hashcat.get_version()

                Color.pl(
                    '{!} {R}'
                    'Hashcat %d.%d.%d does not support mode 22000'
                    '{W}'
                    % version
                )

                from .aircrack import Aircrack

                return Aircrack.crack_handshake(
                    handshake_obj,
                    show_command=show_command,
                    wordlist=wordlist
                )

            Color.pl(
                '{+} {C}'
                'Attempting to crack %s using Hashcat mode %s'
                '{W}'
                % (
                    file_type_msg,
                    hashcat_mode
                )
            )

            key = Hashcat._live_crack(
                hash_file,
                wordlist,
                mode=hashcat_mode,
                show_command=show_command
            )

            if key:
                return key

            # Check potfile even if the live process failed.
            key = Hashcat._check_potfile(
                hash_file,
                mode=hashcat_mode
            )

            if key:
                return key

            return None

        finally:

            if (
                hash_file
                and os.path.exists(hash_file)
            ):
                try:

                    os.remove(hash_file)

                    if Configuration.verbose > 1:
                        Color.pl(
                            '{!} {O}'
                            'Cleaned up temporary hash file'
                            '{W}'
                        )

                except OSError as e:

                    if Configuration.verbose > 0:
                        Color.pl(
                            '{!} {O}'
                            'Warning: Could not remove hash file: %s'
                            '{W}'
                            % str(e)
                        )

    @staticmethod
    def crack_pmkid(
        pmkid_file,
        verbose=False,
        wordlist=None
    ):
        """
        Crack a supplied 22000 hash file.
        """

        if not Hashcat.supports_mode_22000():

            version = Hashcat.get_version()

            Color.pl(
                '{!} {R}'
                'Hashcat %d.%d.%d does not support mode 22000'
                '{W}'
                % version
            )

            return None

        wordlist = (
            wordlist
            or Configuration.wordlist
        )

        key = Hashcat._live_crack(
            pmkid_file,
            wordlist,
            mode='22000',
            show_command=verbose
        )

        if key:
            return key

        return Hashcat._check_potfile(
            pmkid_file,
            mode='22000'
        )
