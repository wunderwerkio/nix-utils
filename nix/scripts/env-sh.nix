{pkgs, ...}:
pkgs.writeShellScript "env.sh" ''
  # Load .env files.
  #
  # Loads given .env files into the current
  # environment.
  #
  # @Arguments
  #   --cwd=<path>    Specify the current working directory.
  #   --verbose       Print verbose messages.
  #   <files>         The .env files to load (can be multiple).
  #                   Default: .env .env.local
  #
  # @Returns
  #   1 if no .env file could be loaded.
  function load_env_files() {
    local files
    local cwd
    local verbose

    files=()
    cwd=$(pwd)
    verbose=0

    while [[ $# -gt 0 ]]; do
      case $1 in
        --cwd)
          cwd="$2"
          shift
          shift
          ;;
        --cwd=*)
          cwd=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --verbose)
          verbose=1
          shift
          ;;
        *)
          files+=("$1")
          shift
          ;;
      esac
    done

    if [ "''${#files[@]}" -eq 0 ]; then
      files+=(".env")
      files+=(".env.local")
    fi

    # Allow export of env variables.
    set -a

    local found_file=1
    for file in "''${files[@]}"; do
      local path
      path="$cwd/$file"

      if [ -f "$path" ]; then
        source "$path"

        if [ $verbose -eq 1 ]; then
          printf "\e[38;5;242m 🛈 Loaded env variables from file: %s\n\e[0n" "$file"
        fi

        found_file=0
      fi
    done

    # Disable export of env variables.
    set +a

    return $found_file
  }

  # Writes an env var to an env var file.
  #
  # Overwrites existing values.
  #
  # @Arguments
  #   --file=<name>    The filename to write to.
  #   --cwd=<path>     The current working directory.
  #   --name=<name>    The name of the env var.
  #   <value>          The value of the env var.
  function write_to_env_file() {
    local file
    local name
    local value
    local cwd

    file=""
    name=""
    value=""
    cwd=$(pwd)

    while [[ $# -gt 0 ]]; do
      case $1 in
        --cwd=*)
          cwd=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --file=*)
          file=$(echo "$1" | cut -c 8-)
          shift
          ;;
        --name=*)
          name=$(echo "$1" | cut -c 8-)
          shift
          ;;
        *)
          value="$1"
          shift
          ;;
      esac
    done

    local path
    path="$cwd/$file"
    if [ ! -f "$path" ]; then
      touch "$path"
    fi

    ${pkgs.gnugrep}/bin/grep -e "^$name=" &>/dev/null < "$path"
    if [ $? -eq 0 ]; then
      ${pkgs.gnused}/bin/sed -i "s/^$name=.*/$name=$value/" "$path"
    else
      echo "$name=$value" >> "$path"
    fi
  }
''
