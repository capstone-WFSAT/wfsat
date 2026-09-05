#!/usr/bin/env python
# -*- coding: utf-8 -*-

try:
    from .config import Configuration
except (ValueError, ImportError) as e:
    raise Exception("You may need to run wifite from the root directory (which includes README.md)", e) from e


from .util.color import Color

import os
import sys


class Wifite:

    def __init__(self):
        """
        Initializes Wifite.
        """
        self.print_banner()

        Configuration.initialize(load_interface=False)

        from .util.tui_logger import TUILogger
        if hasattr(Configuration, 'tui_debug') and Configuration.tui_debug:
            TUILogger.initialize(enabled=True, debug_mode=True)

        from .util.output import OutputManager
        if Configuration.use_tui is True:
            OutputManager.initialize('tui')
        else:
            OutputManager.initialize('classic')

        if Configuration.syscheck:
            from .util.system_check import run_system_check
            smoke_test = Configuration.verbose > 0
            run_system_check(verbose=Configuration.verbose, smoke_test=smoke_test)
            raise SystemExit(0)

        if os.name == 'nt':
            Color.pl('{!} {R}error: {O}wifite{R} must be run under a {O}*NIX{W}{R} like OS')
            Configuration.exit_gracefully()
        if os.getuid() != 0:
            Color.pl('{!} {R}error: {O}wifite{R} must be run as {O}root{W}')
            Color.pl('{!} {R}re-run with {O}sudo{W}')
            Configuration.exit_gracefully()

        # WPS(bully) 관련 model.wps_result 미완성으로 전체 dependency 체크는 임시 비활성화
        # from .tools.dependency import Dependency
        # Dependency.run_dependency_check()

        self.cleanup_old_sessions()

        self.interface_assignment = None
        self.available_interfaces = []

        # model.interface_info 미완성으로 interface_manager는 임시 비활성화
        self.interface_manager = None

    def start(self):
        """
        Starts target-scan + attack loop, or PMKID passive capture.
        """
        if Configuration.pmkid_passive:
            if Configuration.use_tui is None:
                Configuration.use_tui = True
            Configuration.get_monitor_mode_interface()
            self.passive_pmkid_capture()
        else:
            Configuration.get_monitor_mode_interface()
            self.scan_and_attack()

    @staticmethod
    def cleanup_old_sessions():
        """Automatically cleanup old session files on startup (silent)."""
        try:
            from .util.session import SessionManager
            session_mgr = SessionManager()
            deleted = session_mgr.cleanup_old_sessions(days=7)

            if deleted > 0 and Configuration.verbose > 0:
                Color.pl('{+} {D}Cleaned up {C}%d{D} old session file(s){W}' % deleted)
        except Exception as e:
            if Configuration.verbose > 0:
                Color.pl('{!} {O}Session cleanup error: %s{W}' % str(e))

    @staticmethod
    def print_banner():
        """Displays ASCII art of the highest caliber."""
        Color.pl(r' {G}  .     {C}{D}  ·  {W}{G}     .    {W}')
        Color.pl(r' {G}.´  ·  .{C}{D} · · {W}{G}.  ·  `.  {G}wifite2 {D}%s{W}' % Configuration.version)
        Color.pl(r' {G}:  :  : {C}{D}((·)){W}{G} :  :  :  {W}{D}a wireless auditor by {C}derv82{W}')
        Color.pl(r' {G}`.  ·  `{GR}{D} /│\ {W}{G}´  ·  .´  {W}{D}maintained by {C}kimocoder{W}')
        Color.pl(r' {G}  `     {GR}{D}/─┴─\{W}{G}     ´    {C}{D}https://github.com/kimocoder/wifite2{W}')
        Color.pl('')

    def passive_pmkid_capture(self):
        """
        Run passive PMKID capture mode.
        """
        from .attack.pmkid_passive import AttackPassivePMKID

        if not Configuration.use_tui:
            Color.pl('')
            Color.pl('{+} {C}Starting Passive PMKID Capture Mode{W}')
            Color.pl('{+} {O}This will monitor all networks without deauthentication{W}')
            Color.pl('')

        try:
            tui_controller = None
            if Configuration.use_tui:
                try:
                    from .ui.tui import TUIController
                    tui_controller = TUIController()
                except (ImportError, Exception) as e:
                    Color.pl('{!} {O}Warning: TUI mode failed to load, using classic mode{W}')
                    if Configuration.verbose > 0:
                        Color.pl('{!} {O}TUI Error: %s{W}' % str(e))
                    Configuration.use_tui = False

            attack = AttackPassivePMKID(tui_controller=tui_controller)
            attack.run()

        except KeyboardInterrupt:
            if not Configuration.use_tui:
                Color.pl('')
                Color.pl('{!} {O}Passive capture interrupted by user{W}')

        except Exception as e:
            if not Configuration.use_tui:
                Color.pl('')
                Color.pl('{!} {R}Error during passive PMKID capture:{W}')
                Color.pl('{!} {R}%s{W}' % str(e))
                if Configuration.verbose > 0:
                    import traceback
                    Color.pl('')
                    Color.pl('{!} {D}Stack trace:{W}')
                    Color.pl('{D}%s{W}' % traceback.format_exc())
                Color.pl('')
                Color.pl('{!} {O}Passive capture failed. Check that:{W}')
                Color.pl('{!} {O}  • hcxdumptool and hcxpcapngtool are installed{W}')
                Color.pl('{!} {O}  • Your wireless interface supports monitor mode{W}')
                Color.pl('{!} {O}  • You have sufficient permissions (running as root){W}')

    def scan_and_attack(self):
        """
        1) Scans for targets, asks user to select targets
        2) Attacks each target
        """
        from .util.scanner import Scanner
        from .attack.all import AttackAll

        Color.pl('')

        s = Scanner()
        s.find_targets()
        targets = s.select_targets()

        attacked_targets = AttackAll.attack_multiple(targets, session=None, session_mgr=None)

        Color.pl('{+} Finished attacking {C}%d{W} target(s), exiting' % attacked_targets)


def force_exit_handler(signum, frame):
    import sys
    print('\n[!] Force exiting...')
    sys.exit(1)


def emergency_exit(signum, frame):
    import sys
    print('\n[!] Emergency exit!')
    sys.exit(1)


def main():
    import subprocess
    import signal as _signal

    try:
        wifite = Wifite()
        wifite.start()
    except (OSError, IOError) as e:
        Color.pl('\n{!} {R}System Error{W}: %s' % str(e))
        Color.pl('\n{!} {R}Exiting{W}\n')
    except subprocess.CalledProcessError as e:
        Color.pl('\n{!} {R}Command Failed{W}: %s' % str(e))
        Color.pl('\n{!} {R}Exiting{W}\n')
    except PermissionError as e:
        Color.pl('\n{!} {R}Permission Error{W}: %s' % str(e))
        Color.pl('\n{!} {R}Try running with sudo{W}\n')
    except KeyboardInterrupt:
        Color.pl('\n{!} {O}Interrupted, Shutting down...{W}')
        _signal.signal(_signal.SIGINT, force_exit_handler)
    except Exception as e:
        Color.pl('\n{!} {R}Unexpected Error{W}: %s' % str(e))
        Color.pl('\n{!} {R}Exiting{W}\n')
    finally:
        _signal.signal(_signal.SIGINT, emergency_exit)
        sys.exit(0)


if __name__ == '__main__':
    main()
