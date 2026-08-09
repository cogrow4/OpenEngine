#!/usr/bin/env python3
"""
verify_urls.py - HTTP-HEADs every preview+full URL in manifest.json,
prints a per-item status, and exits non-zero if anything failed.

Run after generate_manifest.py to catch stale links before commit.
"""
import json, urllib.request, urllib.error, sys, time
from pathlib import Path

PLACEHOLDER = "PLACEHOLDER_SELFHOST_NEEDED"
TIMEOUT = 20

def head(url):
    req = urllib.request.Request(url, method="HEAD")
    req.add_header("User-Agent", "Mozilla/5.0 (OpenEngine-verifier)")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.status, r.headers.get("Content-Type",""), r.headers.get("Content-Length","")

def main():
    m = json.load(open(Path(__file__).parent / "manifest.json"))
    failures = []
    n_real = 0
    n_placeholder = 0
    n_ok = 0
    for it in m["items"]:
        is_ph = any(PLACEHOLDER in it[k]["url"] for k in ("preview","full"))
        if is_ph:
            n_placeholder += 1
            print(f"SKIP  placeholder  {it['id']}")
            continue
        n_real += 1
        for k in ("preview","full"):
            url = it[k]["url"]
            try:
                code, ct, size = head(url)
                if 200 <= code < 400:
                    print(f"OK    {code} {ct[:20]:20} {size or '-':>10}  {it['id']:36} [{k}]")
                    n_ok += 1
                else:
                    print(f"FAIL  {code}                {it['id']:36} [{k}]")
                    failures.append((it["id"], k, code, url))
            except urllib.error.HTTPError as e:
                print(f"FAIL  {e.code} (HTTPError)    {it['id']:36} [{k}]")
                failures.append((it["id"], k, e.code, url))
            except Exception as e:
                print(f"FAIL  - ({e}) {it['id']:36} [{k}]")
                failures.append((it["id"], k, -1, url))
            time.sleep(0.05)
    print()
    print(f"verified_items={n_real}  placeholder_items={n_placeholder}")
    print(f"url_checks_ok={n_ok}  url_checks_failed={len(failures)}")
    if failures:
        sys.exit(1)

if __name__ == "__main__":
    main()
