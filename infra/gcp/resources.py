"""Read infra/gcp/resources.yml for the setup scripts, and print the gcloud commands they would run.

    python3 resources.py get buckets.uploads.name        # one value (lists print space-separated)
    python3 resources.py member sa:api                   # an IAM member: serviceAccount:..., allUsers
    python3 resources.py iam project                     # one binding per line: <target> <member> <role>
    python3 resources.py cors-json uploads               # the bucket's CORS file (origins from WEB_ORIGINS)
    python3 resources.py lifecycle-json uploads          # the bucket's lifecycle file
    python3 resources.py index-args                      # one Firestore index per line, as --field-config args
    python3 resources.py ttl-args                        # one Firestore TTL policy per line: <field> --collection-group=<c>
    python3 resources.py --print                         # dry run: every gcloud command setup.sh would run

`${NAME}` in the YAML is filled from the environment, then from config.env (config.env.example if there is
none, so the dry run works anywhere). PROJECT_NUMBER comes only from the environment: the scripts look it
up and pass it in; the dry run leaves it as a placeholder. This file never runs gcloud itself.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
RESOURCES = HERE / "resources.yml"
TOP_KEYS = {"apis", "service_accounts", "service_agents", "buckets", "firestore", "pubsub", "eventarc",
            "cloud_run", "iam"}
IAM_KEYS = {"project", "buckets", "service_accounts", "topics"}
_VAR = re.compile(r"\$\{([A-Z_]+)\}")


class ResourceError(ValueError):
    pass


def config_env(path: Path | None = None) -> dict[str, str]:
    """KEY=VALUE lines of config.env (or config.env.example), without comments."""
    path = path or (HERE / "config.env" if (HERE / "config.env").exists() else HERE / "config.env.example")
    out: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def _fill(value, env: dict[str, str]):
    if isinstance(value, str):
        return _VAR.sub(lambda m: env.get(m[1], m[0]), value)
    if isinstance(value, list):
        return [_fill(v, env) for v in value]
    if isinstance(value, dict):
        return {k: _fill(v, env) for k, v in value.items()}
    return value


def load(env: dict[str, str] | None = None, path: Path = RESOURCES) -> dict:
    """resources.yml with `${NAME}` filled in from `env` (default: config.env, then the environment)."""
    if env is None:
        env = {**config_env(), **os.environ}
    data = _fill(yaml.safe_load(path.read_text()), env)
    check(data)
    return data


def check(data: dict) -> None:
    """Typos fail here, before any script runs: unknown sections, members, buckets or accounts."""
    unknown = set(data) - TOP_KEYS
    if unknown or set(data) != TOP_KEYS:
        raise ResourceError(f"resources.yml: unknown {sorted(unknown)}, missing {sorted(TOP_KEYS - set(data))}")
    iam = data["iam"]
    if set(iam) - IAM_KEYS:
        raise ResourceError(f"iam: unknown sections {sorted(set(iam) - IAM_KEYS)}")
    for section, bindings in iam.items():
        for b in bindings:
            member(data, b["member"])  # raises for an unknown member
            if section == "buckets" and b["bucket"] not in data["buckets"]:
                raise ResourceError(f"iam.buckets: unknown bucket {b['bucket']!r}")
            if section == "service_accounts" and b["account"] not in data["service_accounts"]:
                raise ResourceError(f"iam.service_accounts: unknown account {b['account']!r}")
    if data["eventarc"]["bucket"] not in data["buckets"]:
        raise ResourceError(f"eventarc.bucket: unknown bucket {data['eventarc']['bucket']!r}")


def get(data: dict, dotted: str):
    value = data
    for part in dotted.split("."):
        if not isinstance(value, dict) or part not in value:
            raise ResourceError(f"no {dotted!r} in resources.yml")
        value = value[part]
    return value


def sa_email(data: dict, key: str, project: str) -> str:
    return f"{data['service_accounts'][key]['id']}@{project}.iam.gserviceaccount.com"


def member(data: dict, ref: str, project: str = "${PROJECT_ID}") -> str:
    """`sa:api` -> serviceAccount:craftstream-api@<project>.iam.gserviceaccount.com; `allUsers` stays."""
    if ref == "allUsers":
        return ref
    kind, _, key = ref.partition(":")
    if kind == "sa" and key in data["service_accounts"]:
        return f"serviceAccount:{sa_email(data, key, project)}"
    if kind == "agent" and key in data["service_agents"]:
        return f"serviceAccount:{data['service_agents'][key]['email']}"
    raise ResourceError(f"unknown IAM member {ref!r} (sa:<account>, agent:<agent> or allUsers)")


def iam_lines(data: dict, section: str, project: str) -> list[tuple[str, str, str]]:
    """(target, member, role) per binding. Target: the project, a bucket URL, an account email or the topic."""
    out = []
    for b in data["iam"].get(section, []):
        if section == "buckets":
            target = f"gs://{data['buckets'][b['bucket']]['name']}"
        elif section == "service_accounts":
            target = sa_email(data, b["account"], project)
        elif section == "topics":
            target = data["pubsub"]["topic"]
        else:
            target = project
        out.append((target, member(data, b["member"], project), b["role"]))
    return out


def cors_json(data: dict, bucket: str, origins: str) -> str:
    c = data["buckets"][bucket]["cors"]
    return json.dumps([{"origin": [o.strip() for o in origins.split(",") if o.strip()], "method": c["methods"],
                        "responseHeader": c["response_headers"], "maxAgeSeconds": c["max_age_seconds"]}])


def lifecycle_json(data: dict, bucket: str) -> str:
    lc = data["buckets"][bucket]["lifecycle"]
    days = str(lc["delete_after_days"])  # filled from RAW_RETENTION_DAYS; a placeholder stays text in a dry run
    return json.dumps({"rule": [{"action": {"type": "Delete"}, "condition": {
        "age": int(days) if days.isdigit() else days, "matchesPrefix": [lc["delete_prefix"]]}}]})


def index_args(data: dict) -> list[str]:
    """One line per composite index: --collection-group <c> --field-config ... (gcloud firestore indexes)."""
    lines = []
    for ix in data["firestore"]["indexes"]:
        args = [f"--collection-group {ix['collection']}"]
        for f in ix["fields"]:
            how = f"array-config={f['array']}" if "array" in f else f"order={f['order']}"
            args.append(f"--field-config field-path={f['path']},{how}")
        lines.append(" ".join(args))
    return lines


def ttl_args(data: dict) -> list[str]:
    """One line per TTL policy: <field> --collection-group=<c> (gcloud firestore fields ttls update)."""
    return [f"{t['field']} --collection-group={t['collection']}" for t in data["firestore"].get("ttl", [])]


def dry_run(data: dict, env: dict[str, str]) -> list[str]:
    """The gcloud commands the setup scripts run, in order (existence checks left out)."""
    project, region, service = env.get("PROJECT_ID", "?"), env.get("REGION", "?"), env.get("SERVICE", "?")
    url = f"https://{service}-${{PROJECT_NUMBER}}.{region}.run.app"
    gc = f"gcloud --project {project} --quiet"
    b, ps, ea, cr = data["buckets"], data["pubsub"], data["eventarc"], data["cloud_run"]
    origins = env.get("WEB_ORIGINS", "")
    out = ["# 01_project.sh", f"{gc} services enable {' '.join(data['apis'])}",
           "# 02_storage.sh"]
    for key, bucket in b.items():
        flags = " --public-access-prevention" if not bucket["public"] else ""
        out.append(f"{gc} storage buckets create gs://{bucket['name']} --location {region} "
                   f"--uniform-bucket-level-access{flags}")
        update = f"{gc} storage buckets update gs://{bucket['name']} --cors-file <({cors_json(data, key, origins)})"
        if "lifecycle" in bucket:
            update += f" --lifecycle-file <({lifecycle_json(data, key)})"
        out.append(update)
    out += ["# 03_firestore.sh",
            f"{gc} firestore databases create --location {region} --type {data['firestore']['type']}"]
    out += [f"{gc} firestore indexes composite create {a} --async" for a in index_args(data)]
    out += [f"{gc} firestore fields ttls update {a} --enable-ttl --async" for a in ttl_args(data)]
    out.append("# 04_iam.sh")
    out += [f"{gc} beta services identity create --service {a['service']}" for a in data["service_agents"].values()]
    out.append(f"{gc} storage service-agent")
    out += [f"{gc} iam service-accounts create {sa['id']} --display-name '{sa['display_name']}'"
            for sa in data["service_accounts"].values()]
    for t, m, r in iam_lines(data, "project", project):
        out.append(f"{gc} projects add-iam-policy-binding {t} --member {m} --role {r} --condition None")
    for t, m, r in iam_lines(data, "buckets", project):
        out.append(f"{gc} storage buckets add-iam-policy-binding {t} --member {m} --role {r}")
    for t, m, r in iam_lines(data, "service_accounts", project):
        out.append(f"{gc} iam service-accounts add-iam-policy-binding {t} --member {m} --role {r}")
    out.append(f"{gc} pubsub topics create {ps['topic']}")
    for t, m, r in iam_lines(data, "topics", project):
        out.append(f"{gc} pubsub topics add-iam-policy-binding {t} --member {m} --role {r}")
    auth = "--allow-unauthenticated" if cr["allow_unauthenticated"] else "--no-allow-unauthenticated"
    events_sa, sub = sa_email(data, "events", project), ps["subscription"]
    out.append("# 05_deploy.sh")
    out.append(f"{gc} run deploy {service} --source backend --region {region} "
               f"--service-account {sa_email(data, 'api', project)} {auth} --set-env-vars <see 05_deploy.sh> "
               f"--cpu {cr['cpu']} --memory {cr['memory']} --min-instances {cr['min_instances']} "
               f"--max-instances {cr['max_instances']} --concurrency {cr['concurrency']}")
    out.append("# 06_events.sh")
    out.append(f"{gc} eventarc triggers create {ea['trigger']} --location {region} "
               f"--destination-run-service {service} --destination-run-region {region} "
               f"--destination-run-path {ea['path']} --event-filters type={ea['event_type']} "
               f"--event-filters bucket={b[ea['bucket']]['name']} --service-account {events_sa}")
    out.append(f"{gc} pubsub subscriptions create {sub['name']} --topic {ps['topic']} "
               f"--push-endpoint {url}{sub['push_path']} "
               f"--push-auth-service-account {events_sa} --push-auth-token-audience {url} "
               f"--ack-deadline {sub['ack_deadline_seconds']} --min-retry-delay {sub['min_retry_delay']} "
               f"--max-retry-delay {sub['max_retry_delay']}")
    return out


def _print(value) -> None:
    """Lists print space-separated, sections print their keys (for `for key in $(res get ...)` loops)."""
    print(" ".join(str(v) for v in value) if isinstance(value, list | dict) else value)


def main(argv: list[str]) -> int:
    env = {**config_env(), **os.environ}
    try:
        data = load(env)
        project = env.get("PROJECT_ID", "${PROJECT_ID}")
        match argv:
            case ["--print"] | ["print"]:
                print("\n".join(dry_run(data, env)))
            case ["get", dotted]:
                _print(get(data, dotted))
            case ["member", ref]:
                print(member(data, ref, project))
            case ["iam", section] if section in IAM_KEYS:
                for line in iam_lines(data, section, project):
                    print(" ".join(line))
            case ["cors-json", bucket]:
                print(cors_json(data, bucket, env.get("WEB_ORIGINS", "")))
            case ["lifecycle-json", bucket]:
                print(lifecycle_json(data, bucket))
            case ["index-args"]:
                print("\n".join(index_args(data)))
            case ["ttl-args"]:
                print("\n".join(ttl_args(data)))
            case _:
                print(__doc__, file=sys.stderr)
                return 2
    except (ResourceError, KeyError) as e:
        print(f"resources.yml: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
