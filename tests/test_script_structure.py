import subprocess
import pathlib
import os

def test_powershell_script_structure():
    # locate the PowerShell test script
    ps_test_path = pathlib.Path(__file__).parent.parent / 'tests' / 'test_script_structure.ps1'
    if not ps_test_path.exists():
        raise AssertionError(f"PowerShell test script not found: {ps_test_path}")
    # run the PowerShell script and capture result
    result = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ps_test_path)],
                            capture_output=True, text=True)
    # output for debugging
    print(result.stdout)
    print(result.stderr, file=os.sys.stderr)
    assert result.returncode == 0, f"PowerShell script failed with return code {result.returncode}"
