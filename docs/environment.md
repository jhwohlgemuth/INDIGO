# Environment file contract

INDIGO uses `.env` as the shared input for Make, Docker Compose, and
`scripts/new.sh`. Validate the base file or an instance file before use:

```shell
make check-env
make check-env ENV_FILE=.env.two
```

The validator reads the file as data. It never sources or evaluates it.

```pikchr
scale = 0.8
Env: box ".env or" "instance file" wid 1.1in ht 0.52in rad 0.08in fill 0xF3F0FF thickness 0
arrow right 0.4in thick color 0x5B4BC4
Check: box "scripts/check.sh" wid 1.2in ht 0.52in rad 0.08in fill 0xEDE9FE thickness 0
Make: box "Make" wid 0.85in ht 0.48in rad 0.08in fill 0xE0E7FF thickness 0 at Check+(1.75in,0.7in)
Compose: box "Compose" wid 0.85in ht 0.48in rad 0.08in fill 0xF3E8FF thickness 0 at Check+(1.75in,0)
New: box "scripts/new.sh" wid 1.05in ht 0.48in rad 0.08in fill 0xF5F3FF thickness 0 at Check+(1.75in,-0.7in)
arrow from Check.e right 0.3in then up until even with Make then to Make.w thick color 0x5B4BC4
arrow from Check.e to Compose.w thick color 0x5B4BC4
arrow from Check.e right 0.3in then down until even with New then to New.w thick color 0x5B4BC4
```

## Supported grammar

An environment file may contain:

- blank lines;
- comments whose first character is `#`;
- one unquoted `KEY=VALUE` assignment per line.

Keys use letters, digits, and underscores and cannot start with a digit. Values
use the deliberately small common subset accepted consistently by the project:
letters, digits, `.`, `_`, `/`, `:`, `@`, `,`, `+`, and `-`. Empty optional
values are allowed; every required value must be nonempty.

Both LF and CRLF line endings are accepted. The validator strips one terminal
carriage return before parsing each line.

The following forms are rejected rather than interpreted differently by Make,
Compose, or a shell:

```dotenv
export IMAGE=indigo
 IMAGE=indigo
IMAGE =indigo
IMAGE="indigo"
IMAGE=indigo # comment
IMAGE=$(command)
```

Put comments on their own lines. Define every active key once; duplicate
optional keys fail just like duplicate required keys.

## Required typed values

`scripts/check.sh` requires the image identity, instance identity, resource
settings, publish address, and every published service port used by the base
Compose file. It also applies these type checks:

- image tags use OCI tag-compatible characters;
- `REGISTRY` is a hostname with an optional decimal port;
- `REGISTRY_PROJECT` and `IMAGE` are lowercase OCI names;
- `NOTEBOOK_DIGEST` is `sha256:` followed by 64 lowercase hexadecimal digits;
- host fields contain a hostname or IP address, not a URL scheme or port;
- shared-memory size and stop grace period use positive explicit units.

Additional safe assignments are allowed for documented Compose and image
overrides. They still follow the same grammar and uniqueness rules.

## Decimal port rules

Published ports and optional `INDIGO_MLX_PORT` must contain only decimal digits
and represent values from 1 through 65535. Leading zeros are accepted and are
explicitly interpreted in base 10, so `08` means port 8 rather than an octal
number. Canonically equal spellings collide: `08` and `8` cannot be assigned to
two services.

Validation detects duplicate ports inside the file. It does not reserve a host
port or guarantee that another process is not listening; Docker remains the
authority when the stack binds its ports.

## Error behavior

Every diagnostic names the field or line and the environment file. The
validator reports all errors it can find in one pass, prints a final invalid
file summary, and exits nonzero. A valid file prints the required-field count
and exits zero.

`scripts/new.sh` validates its base and generated files with this same contract.
Transactional output and base-instance collision handling belong to the
instance-generation workflow; environment grammar validation does not modify
files.
