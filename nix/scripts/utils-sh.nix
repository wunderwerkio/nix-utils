{pkgs, ...}:
pkgs.writeShellScript "utils.sh" ''
  # Get length of passed in string.
  #
  # This correctly counts the number of characters
  # regardless of unicode or ASCII.
  # Additionally strips al ANSI escape codes for
  # proper length calculation.
  #
  # @Arguments
  #   <text>   Text to get length for
  #
  # @Returns
  #   The number of characters in the text.
  function get_str_len() {
    local clean_text
    clean_text=$(echo -e "$1" | ${pkgs.colorized-logs}/bin/ansi2txt)

    echo ''${#clean_text}
  }

  # Get the project root path.
  #
  # This function searches for a given anchor file
  # that indicates the project root (flake.nix by default).
  # The search starts from the current working directory and
  # continues upwards until system root.
  #
  # @Arguments
  #   <anchor_file>   The file to look for to treat as project root.
  #                   Default: flake.nix
  function get_project_root() {
    local anchor_file
    local cwd

    anchor_file="$1"
    if [ -z "$anchor_file" ]; then
      anchor_file="flake.nix"
    fi

    cwd=$(pwd)

    while [[ "$cwd" != "/" ]]; do
      local flake_file
      flake_file="$cwd/$anchor_file"

      if [[ -e "$flake_file" ]]; then
        break
      fi

      cwd=$(dirname "$cwd")
    done

    echo "$cwd"
  }
''
