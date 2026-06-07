#!/usr/bin/env python3
"""Sync compliance/client-config.yaml to iOS bundled JSON and print config-svc seed values."""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "compliance" / "client-config.yaml"
FILINGS_PATH = ROOT / "compliance" / "algorithm-filing" / "filings.yaml"
BUNDLED_JSON_PATH = (
    ROOT
    / "ios"
    / "Packages"
    / "BabyCameraSettings"
    / "Resources"
    / "ComplianceBundledConfig.json"
)


def load_config() -> dict:
    with CONFIG_PATH.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def build_bindings(models: dict) -> dict:
    bindings: dict[str, dict[str, str]] = {}
    for adapter, entry in models.items():
        bindings[adapter] = {
            "gen_ai_filing_no": entry["gen_ai_filing_no"],
            "deep_synth_filing_no": entry["deep_synth_filing_no"],
        }
    return bindings


def write_filings_yaml(config: dict) -> None:
    models = config["algorithm_filing"]["models"]
    lines = [
        "# CN 模型算法备案号绑定（T7.1 / COMP-01）",
        "# 单一数据源：compliance/client-config.yaml → scripts/sync-compliance-config.py",
        "# 环境变量可覆盖：FILING_<ADAPTER>_GEN_AI / FILING_<ADAPTER>_DEEP_SYNTH",
        "algorithm_filing:",
    ]
    for adapter, entry in models.items():
        lines.append(f"  {adapter}:")
        lines.append(f'    gen_ai_filing_no: "{entry["gen_ai_filing_no"]}"')
        lines.append(f'    deep_synth_filing_no: "{entry["deep_synth_filing_no"]}"')
    FILINGS_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {FILINGS_PATH.relative_to(ROOT)}")


def write_bundled_json(config: dict) -> None:
    payload = {
        "version": config["version"],
        "status": config["status"],
        "icp_number": config["icp"]["number"],
        "icp_query_url": config["icp"]["query_url"],
        "algorithm_filing_summary": config["algorithm_filing"]["summary"],
    }
    BUNDLED_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    with BUNDLED_JSON_PATH.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"wrote {BUNDLED_JSON_PATH.relative_to(ROOT)}")


def print_config_svc_seeds(config: dict) -> None:
    bindings = build_bindings(config["algorithm_filing"]["models"])
    print("\nconfig-svc seed values (compliance/* feature flags):")
    print(f'  compliance.icp_number = "{config["icp"]["number"]}"')
    print(f'  compliance.icp_query_url = "{config["icp"]["query_url"]}"')
    print(
        f'  compliance.algorithm_filing_summary = "{config["algorithm_filing"]["summary"]}"'
    )
    print(
        "  compliance.algorithm_filing_bindings = "
        + json.dumps(bindings, ensure_ascii=False, separators=(",", ":"))
    )


def main() -> int:
    if not CONFIG_PATH.exists():
        print(f"missing {CONFIG_PATH}", file=sys.stderr)
        return 1
    config = load_config()
    write_filings_yaml(config)
    write_bundled_json(config)
    print_config_svc_seeds(config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
