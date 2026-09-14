'''
MIT License

Copyright (c) 2026 Roger Arnett
Copyright (c) 2026 Expert Sleepers Ltd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
'''

'''
Periodically reports CPU usage from a disting NT and maintains running
statistics until interrupted with Ctrl+C.

Requirements:
Python 3
pip install mido
pip install python-rtmidi

Example usage:

python measure_cpu_avg.py 0
  Request CPU usage from the disting NT with SysEx ID 0 every 5 seconds.

python measure_cpu_avg.py 0 10
  Request CPU usage from the disting NT with SysEx ID 0 every 10 seconds.

The first argument is the disting NT SysEx ID (normally 0 unless it has been
changed in the device settings). The optional second argument is the sampling
interval in whole seconds; it defaults to 5 and cannot be less than 1.

Each output line contains the elapsed running time followed by the current,
lowest, highest, and running average percentages for both values reported by
the NT: audio-thread total usage and overall usage. The script also wakes the
NT immediately and once per minute to prevent the screensaver from affecting
the measurements. Press Ctrl+C to stop.
'''

import argparse
import sys
import time

import mido


MANUFACTURER_ID = (0x00, 0x21, 0x27, 0x6D)
CPU_USAGE_COMMAND = 0x62
RESPONSE_TIMEOUT_SECONDS = 1.0
WAKE_COMMAND = 0x07
WAKE_INTERVAL_SECONDS = 60


class RunningStatistics:
    def __init__(self):
        self.count = 0
        self.total = 0
        self.low = None
        self.high = None

    def add(self, value):
        self.count += 1
        self.total += value
        self.low = value if self.low is None else min(self.low, value)
        self.high = value if self.high is None else max(self.high, value)

    @property
    def average(self):
        return self.total / self.count


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Measure disting NT CPU usage until interrupted with Ctrl+C."
    )
    parser.add_argument("sysex_id", type=int, help="disting NT SysEx ID (0-127)")
    parser.add_argument(
        "interval",
        type=int,
        nargs="?",
        default=5,
        help="whole seconds between requests (default: 5; minimum: 1)",
    )
    arguments = parser.parse_args()
    if not 0 <= arguments.sysex_id <= 0x7F:
        parser.error("sysex_id must be between 0 and 127")
    if arguments.interval < 1:
        parser.error("interval must be at least one second")
    return arguments


def is_cpu_usage_response(message, sysex_id):
    # Mido's .data excludes F0 and F7. The command byte is therefore index 5.
    return (
        message.type == "sysex"
        and len(message.data) >= 8
        and tuple(message.data[:4]) == MANUFACTURER_ID
        and message.data[4] == sysex_id
        and message.data[5] == CPU_USAGE_COMMAND
    )


def request_cpu_usage(output_port, input_port, sysex_id):
    request = [0xF0, *MANUFACTURER_ID, sysex_id, CPU_USAGE_COMMAND, 0xF7]
    output_port.send(mido.Message.from_bytes(request))

    deadline = time.monotonic() + RESPONSE_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        response = input_port.poll()
        if response is not None:
            if is_cpu_usage_response(response, sysex_id):
                # The first two response bytes are audio-thread and overall usage.
                return response.data[6], response.data[7]
        time.sleep(0.001)
    return None


def wake_from_screensaver(output_port, sysex_id):
    request = [0xF0, *MANUFACTURER_ID, sysex_id, WAKE_COMMAND, 0xF7]
    output_port.send(mido.Message.from_bytes(request))


def format_statistics(label, current, statistics):
    # CPU values range from 0 to 100, so reserve three characters for each
    # integer value. This keeps the following labels aligned as values grow.
    return (
        f"{label} current={current:<3d} low={statistics.low:<3d} "
        f"high={statistics.high:<3d} avg={statistics.average:<5.1f}"
    )


def main():
    arguments = parse_arguments()

    output_names = [name for name in mido.get_output_names() if "disting NT" in name]
    input_names = [name for name in mido.get_input_names() if "disting NT" in name]
    if not output_names or not input_names:
        print("Could not find disting NT MIDI input and output ports.", file=sys.stderr)
        return 1

    audio_statistics = RunningStatistics()
    overall_statistics = RunningStatistics()
    start_time = time.monotonic()
    next_request_time = start_time
    next_wake_time = start_time

    with mido.open_output(output_names[0]) as output_port, mido.open_input(input_names[0]) as input_port:
        print("Measuring CPU usage; press Ctrl+C to stop.")
        try:
            while True:
                now = time.monotonic()
                next_event_time = min(next_request_time, next_wake_time)
                if now < next_event_time:
                    time.sleep(next_event_time - now)

                now = time.monotonic()
                if now >= next_wake_time:
                    wake_from_screensaver(output_port, arguments.sysex_id)
                    # Maintain a minute-based schedule, but do not send a burst
                    # of wake messages if the machine was suspended.
                    while next_wake_time <= now:
                        next_wake_time += WAKE_INTERVAL_SECONDS

                if now >= next_request_time:
                    result = request_cpu_usage(output_port, input_port, arguments.sysex_id)
                    elapsed_seconds = int(time.monotonic() - start_time)
                    if result is not None:
                        audio_usage, overall_usage = result
                        audio_statistics.add(audio_usage)
                        overall_statistics.add(overall_usage)
                        print(
                            f"{elapsed_seconds:8d}s  "
                            + format_statistics("AUDIO", audio_usage, audio_statistics)
                            + "   "
                            + format_statistics("OVERALL ", overall_usage, overall_statistics)
                        )

                    # Keep the requested interval based on the original schedule,
                    # so response processing time does not accumulate as drift.
                    next_request_time += arguments.interval
                    next_request_time = max(next_request_time, time.monotonic())
        except KeyboardInterrupt:
            elapsed = time.monotonic() - start_time
            print(f"\nStopped after {int(elapsed)}s ({audio_statistics.count} samples).")

    return 0


if __name__ == "__main__":
    sys.exit(main())
