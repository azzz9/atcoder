"""Runtime patch for online-judge-tools on AtCoder memory unit changes.

AtCoder switched memory unit labels from MB/KB to MiB/KiB. The currently
packaged online-judge-api-client in this environment asserts on those labels.
This patch normalizes the HTML before the original parser runs.
"""

from __future__ import annotations

import builtins
from typing import Any


def _normalize_memory_units(html: Any) -> Any:
    if isinstance(html, (bytes, bytearray)):
        return html.replace(b" MiB", b" MB").replace(b" KiB", b" KB")
    if isinstance(html, str):
        return html.replace(" MiB", " MB").replace(" KiB", " KB")
    return html


def _patch_onlinejudge_atcoder_parser() -> bool:
    try:
        import onlinejudge.service.atcoder as atcoder
    except Exception:
        return False

    original = atcoder.AtCoderProblemData._from_html.__func__
    if getattr(original, "_atcoder_memory_unit_patch", False):
        return True

    def patched(
        cls,
        html: bytes,
        *,
        problem,
        session=None,
        response=None,
        timestamp=None,
    ):
        return original(
            cls,
            _normalize_memory_units(html),
            problem=problem,
            session=session,
            response=response,
            timestamp=timestamp,
        )

    patched._atcoder_memory_unit_patch = True  # type: ignore[attr-defined]
    atcoder.AtCoderProblemData._from_html = classmethod(patched)
    return True


if not _patch_onlinejudge_atcoder_parser():
    _orig_import = builtins.__import__

    def _import_hook(name, globals=None, locals=None, fromlist=(), level=0):
        module = _orig_import(name, globals, locals, fromlist, level)
        if name == "onlinejudge.service.atcoder" or name.startswith("onlinejudge"):
            if _patch_onlinejudge_atcoder_parser():
                builtins.__import__ = _orig_import
        return module

    builtins.__import__ = _import_hook
