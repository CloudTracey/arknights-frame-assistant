#!/usr/bin/env python3
"""Build and upload version.json to Tencent Cloud COS.

Retrieves all historical releases from GitHub API (via --releases-file JSONL)
and writes them into version.json so the domestic CDN source carries the exact
same changelog data as the GitHub source.

Falls back to downloading the existing version.json from COS when the releases
file is unavailable.

When --sync-both is set, both stable/version.json and beta/version.json are
updated with the same full releases array, ensuring changelog consistency
regardless of which channel the user selects in AFA.
"""
import argparse
import json
import os
import re
import sys
import tempfile

from qcloud_cos import CosConfig, CosS3Client


def build_version_json(channel, version, date, body, domain, github_releases):
    """Build version.json content.

    Args:
        github_releases: List of release dicts parsed from GitHub API JSONL.
                         Each dict has: tag_name, body, published_at, prerelease,
                         assets (list of {browser_download_url}).
                         May be empty to trigger COS fallback.
    """
    download_url = f"https://{domain}/{channel}/{version}/AFA.exe"

    if github_releases:
        releases = []
        seen_versions = set()
        for rel in github_releases:
            tag = rel.get("tag_name", "")
            if not tag or tag in seen_versions:
                continue
            seen_versions.add(tag)

            published_at = rel.get("published_at", "")
            release_date = published_at[:10] if published_at else ""

            # Extract first asset download URL (AFA.exe)
            asset_url = ""
            assets = rel.get("assets", [])
            if assets:
                asset_url = assets[0].get("browser_download_url", "")

            releases.append({
                "tag_name": tag,
                "body": rel.get("body", ""),
                "published_at": published_at,
                "date": release_date,
                "prerelease": rel.get("prerelease", False),
                "browser_download_url": asset_url,
            })

        # If the current version is NOT in GitHub releases (e.g. manual
        # dispatch for a brand-new release), prepend it.
        if version not in seen_versions:
            releases.insert(0, {
                "tag_name": version,
                "body": body,
                "published_at": date,
                "date": date,
                "prerelease": (channel == "beta"),
                "browser_download_url": download_url,
            })

        print(f"Built releases array with {len(releases)} entries (from GitHub API)")
    else:
        # Fallback: single release — the COS merge path will extend it
        releases = [{
            "tag_name": version,
            "body": body,
            "published_at": date,
            "date": date,
            "prerelease": (channel == "beta"),
            "browser_download_url": download_url,
        }]

    return {
        "version": version,
        "downloadUrl": download_url,
        "date": date,
        "body": body,
        "releases": releases,
    }


def get_cos_client():
    """Create COS client from environment variables."""
    config = CosConfig(
        Region=os.environ["COS_REGION"],
        SecretId=os.environ["COS_SECRET_ID"],
        SecretKey=os.environ["COS_SECRET_KEY"],
    )
    return CosS3Client(config)


def download_existing_releases(cos_client, bucket, channel):
    """Download existing releases array from COS. Returns empty list on failure."""
    key = f"{channel}/version.json"
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            tmp_path = f.name
        cos_client.download_file(
            Bucket=bucket,
            Key=key,
            DestFilePath=tmp_path,
        )
        with open(tmp_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("releases", [])
    except Exception as e:
        print(f"Warning: Failed to download existing releases from {key}: {e}", file=sys.stderr)
        return []
    finally:
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


def upload_version_json(cos_client, bucket, channel, data):
    """Upload version.json to COS."""
    key = f"{channel}/version.json"
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", encoding="utf-8", delete=False
        ) as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            tmp_path = f.name
        cos_client.upload_file(
            Bucket=bucket,
            Key=key,
            LocalFilePath=tmp_path,
        )
        print(f"Uploaded {key}")
    finally:
        if tmp_path is not None:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


def _version_key(tag):
    """Convert a version tag (e.g. 'v1.5.7' or 'v1.5.7-beta1') into a
    sortable tuple so that max() returns the semantically highest version.

    Follows SemVer 2.0 precedence: a stable release sorts HIGHER than any
    prerelease of the same major.minor.patch (1.5.7 > 1.5.7-beta1).
    """
    v = re.sub(r"^[vV]", "", tag)

    # Split core version from optional prerelease suffix
    if "-" in v:
        core, pre = v.split("-", 1)
        pre_parts = re.split(r"[.]", pre)
        pre_key = []
        for p in pre_parts:
            try:
                pre_key.append((0, int(p)))
            except ValueError:
                pre_key.append((1, p))
        is_stable = 0  # prerelease → lower priority
        pre_tuple = tuple(pre_key)
    else:
        core = v
        is_stable = 1  # stable → higher priority
        pre_tuple = ()

    core_parts = [int(x) for x in core.split(".")]
    while len(core_parts) < 3:
        core_parts.append(0)

    # (core, is_stable, prerelease) — is_stable=1 beats is_stable=0
    return (tuple(core_parts), is_stable, pre_tuple)


def _find_latest_for_channel(releases, channel):
    """Return the latest release dict for *channel* ('stable' or 'beta').

    *releases* is a list of dicts as returned by :func:`load_github_releases`.
    Returns ``None`` when no release matches the channel.
    """
    want_prerelease = channel == "beta"
    candidates = [r for r in releases if r.get("prerelease", False) == want_prerelease]
    if not candidates:
        return None
    return max(candidates, key=lambda r: _version_key(r.get("tag_name", "")))


def load_github_releases(filepath):
    """Load releases from a JSONL file produced by `gh api --paginate --jq`.

    Each line is a standalone JSON object with keys:
    tag_name, body, published_at, prerelease, assets.
    """
    releases = []
    if not filepath or not os.path.exists(filepath):
        return releases

    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                releases.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"Warning: Skipping malformed JSON line: {e}", file=sys.stderr)

    return releases


def _upload_for_channel(cos_client, bucket, channel, version, date, body, domain,
                        github_releases, is_current):
    """Build and upload version.json for a single channel.

    When *is_current* is True this is the release being published right now;
    its version/date/body is used as the authoritative top-level data.  When
    False it is the *other* channel being synced — its top-level data comes
    from the latest matching release found in *github_releases*.
    """
    data = build_version_json(
        channel, version, date, body, domain, github_releases
    )

    if github_releases:
        upload_version_json(cos_client, bucket, channel, data)
    else:
        # Fallback: merge with existing releases on COS
        existing_releases = download_existing_releases(cos_client, bucket, channel)
        existing_versions = {r["tag_name"] for r in existing_releases}
        if version not in existing_versions:
            data["releases"].extend(existing_releases)
        upload_version_json(cos_client, bucket, channel, data)

    tag = " (current)" if is_current else " (synced)"
    print(f"version.json updated: {version} ({channel}){tag}")


def main():
    parser = argparse.ArgumentParser(description="Build and upload version.json")
    parser.add_argument("--channel", required=True, choices=["stable", "beta"])
    parser.add_argument("--version", required=True)
    parser.add_argument("--date", required=True)
    parser.add_argument(
        "--body",
        default="",
        help="Release body text (use --body-file to read from file, preferred for safety)",
    )
    parser.add_argument(
        "--body-file",
        default=None,
        help="Path to file containing release body (safer than --body for special characters)",
    )
    parser.add_argument("--domain", required=True)
    parser.add_argument(
        "--releases-file",
        default=None,
        help="Path to JSONL file of all GitHub releases (from gh api --paginate --jq)",
    )
    parser.add_argument(
        "--sync-both",
        action="store_true",
        help="Also update the other channel's version.json with the same full releases array",
    )
    args = parser.parse_args()

    # Read body from file if --body-file is provided, otherwise use --body directly
    if args.body_file:
        with open(args.body_file, "r", encoding="utf-8") as f:
            body = f.read()
    else:
        body = args.body

    # Load all historical releases from GitHub API
    github_releases = load_github_releases(args.releases_file)
    if github_releases:
        print(f"Loaded {len(github_releases)} releases from {args.releases_file}")

    cos_client = get_cos_client()
    bucket = os.environ["COS_BUCKET"]

    # Always upload for the current (triggering) channel first
    _upload_for_channel(
        cos_client, bucket, args.channel, args.version, args.date, body,
        args.domain, github_releases, is_current=True,
    )

    # Optionally sync the other channel so both version.json files carry the
    # same full releases array — this keeps changelogs consistent regardless
    # of which channel the user selects in AFA.
    if args.sync_both:
        other_channel = "beta" if args.channel == "stable" else "stable"
        other_latest = _find_latest_for_channel(github_releases, other_channel)

        if other_latest is not None:
            other_version = other_latest.get("tag_name", "")
            other_date = (other_latest.get("published_at", "") or "")[:10]
            other_body = other_latest.get("body", "")
            if other_version:
                _upload_for_channel(
                    cos_client, bucket, other_channel, other_version,
                    other_date, other_body, args.domain, github_releases,
                    is_current=False,
                )
            else:
                print(f"Skipping {other_channel}: latest release has no tag_name")
        else:
            print(
                f"Skipping {other_channel}: no releases found for that channel "
                f"in GitHub API data"
            )


if __name__ == "__main__":
    main()
