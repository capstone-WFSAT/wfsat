#!/usr/bin/env python
# -*- coding: utf-8 -*-

try:
    from .config import Configuration
except (ValueError, ImportError) as e:
    raise Exception("You may need to run wifite from the root directory (which includes README.md)", e) from e

from .util.color import Color
import os
import sys


class Wifi:

    def __init__(self):
        Configuration.initialize(load_interface=False)

        if os.name == 'nt':
            Color.pl('{!} {R}error: {O}wfsat{R} must be run under a {O}*NIX{W}{R} like OS')
            sys.exit(1)
        if os.getuid() != 0:
            Color.pl('{!} {R}error: {O}wfsat{R} must be run as {O}root{W}')
            Color.pl('{!} {R}re-run with {O}sudo{W}')
            sys.exit(1)

        from .tools.dependency import Dependency
        Dependency.run_dependency_check()

    def start(self):
        # 지금은 passive PMKID 캡처 모드만 지원
        Configuration.get_monitor_mode_interface()
        self.passive_pmkid_capture()

    def passive_pmkid_capture(self):
        from .attack.pmkid_passive import AttackPassivePMKID

        Color.pl('')
        Color.pl('{+} {C}Starting Passive PMKID Capture Mode{W}')
        Color.pl('')

        try:
            attack = AttackPassivePMKID()
            attack.run()
        except KeyboardInterrupt:
            Color.pl('')
            Color.pl('{!} {O}Passive capture interrupted by user{W}')
        except Exception as e:
            Color.pl('')
            Color.pl('{!} {R}Error during passive PMKID capture:{W} %s' % str(e))
            if Configuration.verbose > 0:
                import traceback
                Color.pl('{D}%s{W}' % traceback.format_exc())


def main():
    try:
        wifi = Wifi()
        wifi.start()
    except KeyboardInterrupt:
        Color.pl('\n{!} {O}Interrupted, exiting...{W}')
        sys.exit(1)
    except Exception as e:
        Color.pl('\n{!} {R}Unexpected Error{W}: %s' % str(e))
        sys.exit(1)


if __name__ == '__main__':
    main()
