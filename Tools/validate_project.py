#!/usr/bin/env python3
"""Static validation that can run without Xcode (Linux/macOS).

Checks:
  * AICat.xcodeproj/project.pbxproj parses (OpenStep plist) and every 24-hex id it references exists.
  * Config/Info.plist and AICat/Resources/PrivacyInfo.xcprivacy are valid plists with the expected keys.
  * The .xcstrings catalogs are valid JSON and every key has non-empty en + es values.
  * Every localization key referenced from Swift (L10n.string/text/format("…") and TextKey("…")) exists.
  * Package sources only import Foundation (no UIKit / SwiftUI / RealityKit in AICatCore).
  * No `#Preview` blocks (cannot be compile-checked here) and no `UIScreen.main` usage.
  * Files under AICat/Layout/Duo are wrapped in `#if AICAT_DUO`.
Exit code 1 on any error.
"""
import json
import os
import plistlib
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors, warnings = [], []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def swift_files(sub):
    for base, _dirs, files in os.walk(os.path.join(ROOT, sub)):
        for name in files:
            if name.endswith(".swift"):
                yield os.path.join(base, name)


def check_pbxproj():
    path = os.path.join(ROOT, "AICat.xcodeproj", "project.pbxproj")
    text = open(path, encoding="utf-8").read()
    try:
        import openstep_parser as osp
    except ImportError:
        warn("openstep_parser not installed (pip install openstep_parser); skipping pbxproj parse")
        return
    with open(path, encoding="utf-8") as f:
        tree = osp.OpenStepDecoder.ParseFromFile(f)
    objs = tree["objects"]
    refs = set(re.findall(r"\b([0-9A-F]{24})\b", text))
    missing = refs - set(objs.keys())
    if missing:
        err(f"pbxproj references unknown object ids: {sorted(missing)}")
    root = objs.get(tree.get("rootObject", ""), {})
    if root.get("isa") != "PBXProject":
        err("pbxproj rootObject is not a PBXProject")
    targets = [o for o in objs.values() if o.get("isa") == "PBXNativeTarget"]
    if len(targets) != 1:
        err(f"expected exactly one native target, found {len(targets)}")
    for t in targets:
        for gid in t.get("fileSystemSynchronizedGroups", []):
            g = objs.get(gid, {})
            if g.get("isa") != "PBXFileSystemSynchronizedRootGroup":
                err(f"target {t.get('name')} sync group {gid} is not a synchronized root group")
            elif not os.path.isdir(os.path.join(ROOT, g.get("path", ""))):
                err(f"synchronized folder missing on disk: {g.get('path')}")
        for pid in t.get("packageProductDependencies", []):
            if objs.get(pid, {}).get("isa") != "XCSwiftPackageProductDependency":
                err(f"packageProductDependencies entry {pid} has wrong isa")
    for o in objs.values():
        if o.get("isa") == "XCLocalSwiftPackageReference":
            rel = o.get("relativePath", "")
            if not os.path.isfile(os.path.join(ROOT, rel, "Package.swift")):
                err(f"local package {rel} has no Package.swift")
    for o in objs.values():
        if o.get("isa") == "XCBuildConfiguration":
            bs = o.get("buildSettings", {})
            info = bs.get("INFOPLIST_FILE")
            if info and not os.path.isfile(os.path.join(ROOT, info)):
                err(f"INFOPLIST_FILE missing: {info}")
    print(f"pbxproj: {len(objs)} objects, {len(refs)} referenced ids, ok")


def check_plists():
    info = os.path.join(ROOT, "Config", "Info.plist")
    with open(info, "rb") as f:
        d = plistlib.load(f)
    for key in ("CFBundleIdentifier", "UILaunchScreen", "UISupportedInterfaceOrientations", "LSRequiresIPhoneOS"):
        if key not in d:
            err(f"Info.plist missing {key}")
    if d.get("UIRequiresFullScreen"):
        err("Info.plist must not set UIRequiresFullScreen (iPhone Duo guidance)")
    if len(d.get("UISupportedInterfaceOrientations", [])) != 4:
        err("Info.plist should support all four orientations")
    for key in d:
        if key.startswith("NS") and key.endswith("UsageDescription"):
            warn(f"Info.plist declares a permission string ({key}); make sure the feature exists")
    priv = os.path.join(ROOT, "AICat", "Resources", "PrivacyInfo.xcprivacy")
    with open(priv, "rb") as f:
        p = plistlib.load(f)
    if p.get("NSPrivacyTracking") is not False:
        err("PrivacyInfo: NSPrivacyTracking must be false")
    if p.get("NSPrivacyCollectedDataTypes"):
        err("PrivacyInfo: no data collection expected in a Kids app")
    print("plists: ok")


def load_catalog(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    keys = {}
    for key, entry in data.get("strings", {}).items():
        locs = entry.get("localizations", {})
        for lang in ("en", "es"):
            val = locs.get(lang, {}).get("stringUnit", {}).get("value", "")
            if not val:
                err(f"{os.path.basename(path)}: key '{key}' missing {lang}")
        keys[key] = locs
    return keys


def check_strings():
    res = os.path.join(ROOT, "AICat", "Resources")
    catalog = load_catalog(os.path.join(res, "Localizable.xcstrings"))
    load_catalog(os.path.join(res, "InfoPlist.xcstrings"))
    used = set()
    pat = re.compile(r'(?:L10n\.(?:string|text|format)|TextKey)\(\s*"([^"\\]+)"')
    for path in list(swift_files("AICat")) + list(swift_files("Packages")):
        src = open(path, encoding="utf-8").read()
        for key in pat.findall(src):
            used.add(key)
            if key not in catalog:
                err(f"{os.path.relpath(path, ROOT)}: localization key '{key}' not in Localizable.xcstrings")
    # Keys built by interpolation in Curriculum.swift follow fixed patterns: enumerate them.
    for n in range(1, 11):
        for suffix in ("title", "subtitle", "concept", "intro"):
            used.add(f"scenario.{n}.{suffix}")
        used.add(f"dialog.s{n}.intro")
        for k in range(1, 5):
            for suffix in ("title", "goal", "concept"):
                used.add(f"challenge.s{n}.c{k}.{suffix}")
    for key in sorted(used):
        if key not in catalog:
            err(f"derived localization key '{key}' not in Localizable.xcstrings")
    unused = sorted(set(catalog) - used)
    if unused:
        warn(f"{len(unused)} catalog keys not referenced from Swift (fine for data-driven keys): {unused[:8]}{'…' if len(unused) > 8 else ''}")
    print(f"strings: {len(catalog)} keys in catalog, {len(used)} referenced, ok")
    return catalog


def check_swift_hygiene():
    mains = 0
    for path in swift_files("AICat"):
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding="utf-8").read()
        if "#Preview" in src:
            err(f"{rel}: remove #Preview (cannot be compile-checked here)")
        if "UIScreen.main" in src:
            err(f"{rel}: do not use UIScreen.main (iPhone Duo guidance)")
        if "@main" in src:
            mains += 1
        if os.sep + "Duo" + os.sep in rel and not src.lstrip().startswith("#if AICAT_DUO"):
            err(f"{rel}: files in Layout/Duo must start with '#if AICAT_DUO'")
    if mains != 1:
        err(f"expected exactly one @main, found {mains}")
    for path in swift_files("Packages"):
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding="utf-8").read()
        for mod in ("UIKit", "SwiftUI", "RealityKit", "AppKit", "Combine"):
            if re.search(rf"^\s*import\s+{mod}\b", src, re.M):
                err(f"{rel}: AICatCore must stay Foundation-only (imports {mod})")
    print("swift hygiene: ok")


def main():
    check_pbxproj()
    check_plists()
    check_strings()
    check_swift_hygiene()
    for w in warnings:
        print("warning:", w)
    for e in errors:
        print("ERROR:", e)
    print("FAILED" if errors else "ALL CHECKS PASSED")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
