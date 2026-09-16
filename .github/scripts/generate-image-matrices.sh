#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${1:-.github/image-matrix.json}"

jq -e '
  def unique_nonempty_strings:
    type == "array"
    and length > 0
    and all(.[]; type == "string" and length > 0)
    and length == (unique | length);

  . as $config
  | (keys | sort) == ["architectures", "distributions", "drivers", "exclude"]
    and ($config.architectures | unique_nonempty_strings)
    and ($config.drivers | unique_nonempty_strings)
    and ($config.distributions | unique_nonempty_strings)
    and ($config.exclude | type == "array")
    and all(
      $config.exclude[];
      type == "object"
      and (keys | sort) == ["dist", "driver"]
      and (.driver as $driver | $config.drivers | index($driver) != null)
      and (.dist as $dist | $config.distributions | index($dist) != null)
    )
    and (
      [$config.exclude[] | [.driver, .dist]]
      | length == (unique | length)
    )
' "$CONFIG_FILE" > /dev/null || {
  echo "Invalid image matrix configuration: $CONFIG_FILE" >&2
  exit 1
}

BUILD_MATRIX=$(jq -c '
  {
    arch: .architectures,
    driver: .drivers,
    dist: .distributions,
    exclude: .exclude
  }
' "$CONFIG_FILE")

MANIFEST_MATRIX=$(jq -ce '
  . as $config
  | {
      include: [
        $config.drivers[] as $driver
        | {
            driver: $driver,
            distributions: (
              [
                $config.distributions[] as $dist
                | select(
                    ($config.exclude | any(.driver == $driver and .dist == $dist))
                    | not
                  )
                | $dist
              ]
              | join(" ")
            )
          }
      ]
    }
  | if all(.include[]; .distributions != "")
    then .
    else error("a driver has no supported distributions")
    end
' "$CONFIG_FILE")

printf 'build_matrix=%s\n' "$BUILD_MATRIX"
printf 'manifest_matrix=%s\n' "$MANIFEST_MATRIX"
