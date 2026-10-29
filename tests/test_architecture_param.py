import pathlib
import re

# Test that Build-MypalPackage.ps1 defines a mandatory Architecture parameter

def test_architecture_parameter_defined():
    script_path = pathlib.Path(__file__).parent.parent / "scripts" / "Build-MypalPackage.ps1"
    assert script_path.exists(), f"Script not found: {script_path}"
    content = script_path.read_text(encoding='utf-8')
    pattern = r"\[Parameter\(Mandatory\)\]\s*\[ValidateSet\('x86',\s*'x64'\)\]\s*\[string\]\s*\$Architecture"
    assert re.search(pattern, content), "Architecture parameter not defined correctly"
