#!/usr/bin/env python3
"""
Process Respawner Daemon for Fight the Machine

Monitors system processes and respawns them when killed by the game.
Processes are classified into DOOM enemy tiers with corresponding respawn delays.
"""

import subprocess
import time
import threading
import logging
import os
import signal
import sys
from typing import Dict, Set, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/var/log/process-respawner.log')
    ]
)
logger = logging.getLogger(__name__)

# DOOM enemy tiers with respawn delays (seconds)
ENEMY_TIERS = {
    'zombieman': (5, 10),      # Basic processes
    'imp': (8, 15),            # Development tools
    'demon': (12, 20),         # Desktop components
    'cacodemon': (15, 25),     # System services
    'baron': (20, 30),         # Critical services
}

# Process classifications
PROCESS_TIERS = {
    'zombieman': ['cat', 'sleep', 'echo', 'head', 'tail', 'yes', 'true', 'false', 'tee', 'wc'],
    'imp': ['vim', 'python', 'python3', 'grep', 'node', 'less', 'more', 'nano', 'find', 'sed', 'awk'],
    'demon': ['xfce4', 'pulseaudio', 'dbus-daemon', 'gvfs', 'tumbler', 'xfdesktop', 'xfwm4', 'xfce4-panel'],
    'cacodemon': ['cron', 'rsyslog', 'NetworkManager', 'cups', 'avahi', 'bluetooth', 'snapd'],
    'baron': ['systemd', 'lightdm', 'Xorg', 'sshd', 'dbus', 'gdm', 'init', 'openbox'],
}

# Processes that should NEVER be respawned
BLACKLIST = {
    'psdoom',
    'doom',
    'start-psdoom',
    'supervisord',
    'python3 /usr/local/bin/process-respawner.py',
    'x11vnc',
    'Xvfb',
    'novnc',
    'websockify',
    'start-vnc',
}

# Track which processes we've seen
known_processes: Dict[int, str] = {}
respawn_threads: Set[int] = set()
running = True


def get_tier(process_name: str) -> Optional[str]:
    """Get the DOOM tier for a process."""
    for tier, processes in PROCESS_TIERS.items():
        if any(p in process_name.lower() for p in processes):
            return tier
    return 'imp'  # Default tier


def get_respawn_delay(tier: str) -> float:
    """Get a random respawn delay for the given tier."""
    import random
    min_delay, max_delay = ENEMY_TIERS.get(tier, (8, 15))
    return random.uniform(min_delay, max_delay)


def is_blacklisted(cmdline: str) -> bool:
    """Check if a process should not be respawned."""
    for blacklisted in BLACKLIST:
        if blacklisted.lower() in cmdline.lower():
            return True
    return False


def get_running_processes() -> Dict[int, str]:
    """Get currently running processes."""
    processes = {}
    try:
        result = subprocess.run(
            ['ps', 'aux', '--no-headers'],
            capture_output=True,
            text=True,
            timeout=5
        )
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split(None, 10)
                if len(parts) >= 11:
                    try:
                        pid = int(parts[1])
                        cmdline = parts[10]
                        processes[pid] = cmdline
                    except (ValueError, IndexError):
                        continue
    except Exception as e:
        logger.error(f"Error getting processes: {e}")
    return processes


def respawn_process(cmdline: str, tier: str):
    """Respawn a killed process after a delay."""
    delay = get_respawn_delay(tier)
    logger.info(f"[{tier.upper()}] Process '{cmdline[:50]}...' killed. Respawning in {delay:.1f}s")

    time.sleep(delay)

    try:
        # Try to respawn the process
        # Extract the base command
        cmd_parts = cmdline.split()
        if cmd_parts:
            base_cmd = cmd_parts[0]

            # For systemd services, try systemctl restart
            if 'systemd' not in base_cmd:
                # Check if it's a service
                service_name = os.path.basename(base_cmd)
                try:
                    subprocess.run(
                        ['systemctl', 'restart', service_name],
                        capture_output=True,
                        timeout=10
                    )
                    logger.info(f"Respawned {service_name} via systemctl")
                    return
                except Exception:
                    pass

            # Direct execution as fallback
            try:
                subprocess.Popen(
                    cmd_parts,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True
                )
                logger.info(f"Respawned '{cmdline[:50]}...' directly")
            except Exception as e:
                logger.warning(f"Could not respawn '{cmdline[:30]}...': {e}")

    except Exception as e:
        logger.error(f"Error respawning process: {e}")


def signal_handler(signum, frame):
    """Handle shutdown signals."""
    global running
    logger.info("Received shutdown signal, stopping...")
    running = False


def main():
    """Main monitoring loop."""
    global known_processes, running

    # Set up signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    logger.info("=" * 50)
    logger.info("Process Respawner Daemon Starting")
    logger.info("=" * 50)
    logger.info("Monitoring processes for game kills...")

    # Initial process snapshot
    known_processes = get_running_processes()
    logger.info(f"Initial snapshot: {len(known_processes)} processes")

    check_interval = 1.0  # seconds
    snapshot_interval = 30  # Take full snapshot every 30 checks
    check_count = 0

    while running:
        try:
            time.sleep(check_interval)
            check_count += 1

            current_processes = get_running_processes()

            # Find killed processes (were in known, not in current)
            killed_pids = set(known_processes.keys()) - set(current_processes.keys())

            for pid in killed_pids:
                cmdline = known_processes.get(pid, '')

                # Skip blacklisted processes
                if is_blacklisted(cmdline):
                    continue

                # Skip if already being respawned
                if pid in respawn_threads:
                    continue

                # Get tier and schedule respawn
                tier = get_tier(cmdline)

                # Start respawn in background thread
                respawn_threads.add(pid)
                thread = threading.Thread(
                    target=respawn_process,
                    args=(cmdline, tier),
                    daemon=True
                )
                thread.start()

            # Update known processes periodically
            if check_count >= snapshot_interval:
                known_processes = current_processes
                check_count = 0
                # Clean up old respawn thread tracking
                respawn_threads.clear()
            else:
                # Update with new processes
                for pid, cmd in current_processes.items():
                    if pid not in known_processes:
                        known_processes[pid] = cmd
                # Remove dead processes
                for pid in killed_pids:
                    known_processes.pop(pid, None)

        except Exception as e:
            logger.error(f"Error in main loop: {e}")
            time.sleep(1)

    logger.info("Process Respawner Daemon stopped")


if __name__ == '__main__':
    main()
