#!/usr/bin/env python3
"""Upload the release AAB to a Google Play track.

Google's Publishing API cannot CREATE an app — the listing and the very first
release must be done by hand in Play Console (see ../README.md § First release).
Every release after that can be done with this script:

    python3 tools/upload-to-play.py --track internal
    python3 tools/upload-to-play.py --track production --rollout 0.1

Setup (once):
    pip install google-api-python-client google-auth
    # Play Console → Users and permissions → invite the service account,
    # grant "Release to testing tracks" + "Release to production".
    # Google Cloud → IAM → Service accounts → Keys → JSON.
    export PLAY_SERVICE_ACCOUNT_JSON=~/salom-ai-play-service-account.json
"""

import argparse
import os
import sys

try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
except ImportError:
    sys.exit("Missing deps. Run: pip install google-api-python-client google-auth")

PACKAGE = "com.feratech.salomai"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
DEFAULT_AAB = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "app", "build", "outputs", "bundle", "release", "app-release.aab",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--track", default="internal",
                        choices=["internal", "alpha", "beta", "production"])
    parser.add_argument("--aab", default=DEFAULT_AAB)
    parser.add_argument("--rollout", type=float, default=None,
                        help="Staged rollout fraction, e.g. 0.1 for 10%%. Omit for a full release.")
    parser.add_argument("--notes-uz", default="Barqarorlik va tezlik yaxshilandi.")
    parser.add_argument("--notes-en", default="Stability and performance improvements.")
    parser.add_argument("--notes-ru", default="Улучшения стабильности и производительности.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Upload the bundle but do not commit the edit.")
    args = parser.parse_args()

    aab = os.path.abspath(args.aab)
    if not os.path.exists(aab):
        sys.exit(f"Bundle not found: {aab}\nRun: ./gradlew :app:bundleRelease")

    key_path = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")
    if not key_path or not os.path.exists(os.path.expanduser(key_path)):
        sys.exit("Set PLAY_SERVICE_ACCOUNT_JSON to your service-account JSON key path.")

    creds = service_account.Credentials.from_service_account_file(
        os.path.expanduser(key_path), scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()

    edit_id = edits.insert(body={}, packageName=PACKAGE).execute()["id"]
    print(f"edit {edit_id}")

    bundle = edits.bundles().upload(
        packageName=PACKAGE, editId=edit_id,
        media_body=MediaFileUpload(aab, mimetype="application/octet-stream", resumable=True),
    ).execute()
    version_code = bundle["versionCode"]
    print(f"uploaded versionCode {version_code}")

    release = {
        "versionCodes": [str(version_code)],
        "status": "inProgress" if args.rollout else "completed",
        "releaseNotes": [
            {"language": "uz", "text": args.notes_uz},
            {"language": "ru-RU", "text": args.notes_ru},
            {"language": "en-US", "text": args.notes_en},
        ],
    }
    if args.rollout:
        release["userFraction"] = args.rollout

    edits.tracks().update(
        packageName=PACKAGE, editId=edit_id, track=args.track,
        body={"track": args.track, "releases": [release]},
    ).execute()
    print(f"assigned to track '{args.track}'"
          + (f" at {args.rollout:.0%} rollout" if args.rollout else ""))

    if args.dry_run:
        edits.delete(packageName=PACKAGE, editId=edit_id).execute()
        print("dry run — edit discarded")
        return

    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print("committed ✓")


if __name__ == "__main__":
    main()
