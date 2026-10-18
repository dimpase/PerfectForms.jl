"""Exercise the selected exporter path with ASan/UBSan and a monitored RSS ceiling.

ASan reserves a large virtual shadow address space, so RLIMIT_AS is inappropriate
at runtime. Builds still have the ordinary 10 GiB virtual-memory limit.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]


def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def resident_bytes(pid):
    if sys.platform.startswith('linux'):
        try:
            values = [int(line.split()[1]) * 1024
                      for line in Path(f'/proc/{pid}/status').read_text().splitlines()
                      if line.startswith(('VmRSS:', 'VmHWM:'))]
            return max(values, default=0)
        except FileNotFoundError:
            return 0
    result = subprocess.run(['ps', '-o', 'rss=', '-p', str(pid)],
                            capture_output=True, text=True, check=False)
    text = result.stdout.strip()
    if text:
        return int(text) * 1024
    if result.returncode not in (0, 1):
        raise RuntimeError('Could not sample resident memory with ps: ' + result.stderr)
    return 0  # The process may have exited between poll() and ps.


def run_case(binary, name, input_text, expected_code, root):
    folder = root / name
    folder.mkdir(parents=True, exist_ok=True)
    source = folder / 'input.nml'
    source.write_text(input_text)
    output = folder / 'output.json'
    # Private fresh output per request; failed prior output remains separately archived.
    if output.exists():
        output.rename(folder / ('previous-' + str(time.time_ns()) + '.json'))
    token = hashlib.sha256((name + str(time.time_ns())).encode()).hexdigest()
    argv = [str(binary), str(source), str(output), token]
    env = dict(os.environ, ASAN_OPTIONS='detect_leaks=1:halt_on_error=1:abort_on_error=1',
               UBSAN_OPTIONS='halt_on_error=1:print_stacktrace=1')
    started = time.monotonic()
    maximum_rss = 0
    reason = None
    with (folder / 'stdout.log').open('w') as stdout, (folder / 'stderr.log').open('w') as stderr:
        process = subprocess.Popen(argv, cwd=folder, stdout=stdout, stderr=stderr,
                                   env=env, preexec_fn=no_core)
        while process.poll() is None:
            maximum_rss = max(maximum_rss, resident_bytes(process.pid))
            if maximum_rss > 10 * 1024**3:
                reason = '10 GiB RSS ceiling'
            elif time.monotonic() - started > 60:
                reason = '60 second deadline'
            if reason:
                process.kill()
                break
            time.sleep(.01)
        code = process.wait()
    stderr_text = (folder / 'stderr.log').read_text()
    clean = not any(marker in stderr_text for marker in
                    ['AddressSanitizer:', 'LeakSanitizer', 'runtime error:', 'UndefinedBehaviorSanitizer:'])
    info = dict(argv=argv, executable_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                input_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                returncode=code, expected_returncode=expected_code, elapsed_seconds=time.monotonic()-started,
                maximum_sampled_rss_bytes=maximum_rss, rss_ceiling_bytes=10*1024**3,
                rss_measurement='linux_proc_status' if sys.platform.startswith('linux') else 'ps_rss_kib',
                deadline_seconds=60, watchdog_failure=reason, sanitizer_clean=clean,
                sanitizer_options={k: env[k] for k in ['ASAN_OPTIONS','UBSAN_OPTIONS']},
                success=code == expected_code and clean and reason is None,
                math_validation='pending' if expected_code == 0 else 'not applicable')
    if code == 0:
        data = json.loads(output.read_text())
        assert data['request_token'] == token and data['completed'] is True
        info['raw_export_sha256'] = hashlib.sha256(output.read_bytes()).hexdigest()
    (folder / 'process.json').write_text(json.dumps(info, indent=2)+'\n')
    print(name, code, f'{info["elapsed_seconds"]:.3f}s', 'clean' if clean else 'SANITIZER FAILURE', flush=True)
    return info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', type=Path,
                        default=PROJECT / 'build-sanitizer/bin/AV_ExportPerfectOrbits')
    parser.add_argument('--fields', action='store_true', help='run D12,D13,D40 instead of the classical/D5/D8 audit')
    parser.add_argument('--output-dir', type=Path, help='retain exports and reports here')
    args = parser.parse_args()
    binary = args.binary.resolve()
    root = (args.output_dir or PROJECT / ('results/sanitizer_fields' if args.fields else 'results/sanitizer')).resolve()
    root.mkdir(parents=True, exist_ok=True)
    # The native smoke-test inputs require no Julia, Oscar or previous run files.
    sys.path.insert(0, str(PROJECT / 'test'))
    from backend_smoke import namelist
    cases = {}
    for discriminant in ((12, 13, 40) if args.fields else (1, 5, 8)):
        name = 'classical2' if discriminant == 1 else f'D{discriminant}'
        cases[name] = run_case(binary, name, namelist(discriminant), 0, root)
    if not args.fields:
        d5 = namelist(5)
        for name, text, expected in [
                ('malformed', '&UNKNOWN_BLOCK\n bad=1\n/\n', 1),
                ('unsupported_arithmetic', d5.replace('arithmetic = "gmp"', 'arithmetic = "flint"'), 64),
                ('unsupported_boundary', d5.replace('ComputeBoundary = F', 'ComputeBoundary = T'), 64)]:
            cases[name] = run_case(binary, name, text, expected, root)
    report = dict(status='passed' if all(c['success'] for c in cases.values()) else 'failed',
                  coverage='selected exporter and instantiated upstream C++ headers; linked nauty/GMP/Boost libraries uninstrumented',
                  cases=cases)
    (root / 'summary.json').write_text(json.dumps(report, indent=2)+'\n')
    raise SystemExit(0 if report['status'] == 'passed' else 1)


if __name__ == '__main__':
    main()
