{pkgs, ...}:
pkgs.writeShellScript "git.sh" ''
  # Add an entry to .gitignore
  #
  # This function adds a new entry to .gitignore if it does not
  # yet exist. Creates a .gitignore if it does not exist.
  #
  # @Arguments
  #   --cwd=<path>    Specify the current working directory.
  #   <line>          Content of the line to add to .gitignore.
  function add_to_gitignore() {
    local cwd

    line=""
    cwd=$(pwd)

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
        *)
          line="$1"
          shift
          ;;
      esac
    done

    local gitignore
    gitignore="$cwd/.gitignore"

    # Create if not exists.
    if [ ! -f "$cwd/.gitignore" ]; then
      touch "$gitignore"
    fi

    ${pkgs.gnugrep}/bin/grep -q "^$line$" "$gitignore"
    if [ $? -ne 0 ]; then
      echo "$line" >> "$gitignore"
    fi
  }
''
