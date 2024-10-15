{pkgs, ...}:
pkgs.writeShellScript "devenv-helper.sh" ''
  #
  # DevEnv Helper Script.
  #
  # This script provides several functions to build
  # individual devenv scripts.
  #

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

  # Print a status line with given type and content.
  #
  # @Arguments
  #   --error         Print status line as error.
  #   --warning       Print status line as warning.
  #   --success       Print status line as success.
  #   --prefix=<text> Will be printed before the line.
  #   <text>          The text to display.
  #
  # Example output:
  #   [✓] Environment variable MY_VAR is set
  #   [✕] Environment variable MY_VAR is not defined
  function print_status_line() {
    local text
    local type
    local prefix

    text=""
    type=""
    prefix=" "

    while [[ $# -gt 0 ]]; do
      case $1 in
        --error)
          type="error"
          shift
          ;;
        --warning)
          type="warning"
          shift
          ;;
        --success)
          type="success"
          shift
          ;;
        --prefix=*)
          prefix=$(echo "$1" | cut -c 10-)
          shift
          ;;
        *)
          text="$1"
          shift
          ;;
      esac
    done

    printf "$prefix\e[38;5;242m["

    case "$type" in
      error)
        printf "\e[31m✕"
        ;;
      warning)
        printf "\e[33m?"
        ;;
      success)
        printf "\e[32m✓"
        ;;
    esac

    printf "\e[38;5;242m]\e[0m $text\n"
  }

  # Check if given env var is set and matches
  # optional criteria.
  #
  # @Arguments
  #   --print-status      Print status line.
  #   --regex=<regex>     Validate env var value by regex.
  #   <env_var_name>      The name of the env var to check.
  #
  # @Returns
  #   0 if env var is set and valid, 1 otherwise.
  function check_env_var() {
    local name
    local print_status
    local regex

    name=""
    print_status=0
    regex=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --print-status)
          print_status=1
          shift
          ;;
        --regex=*)
          regex=$(echo "$1" | cut -c 9-)
          shift
          ;;
        *)
          name="$1"
          shift
          ;;
      esac
    done

    if [[ ! -v "$name" ]]; then
      if [ $print_status -eq 1 ]; then
        print_status_line --error "Environment variable \e[3;1m$name\e[0m is not defined" 1>&2
      fi

      return 1
    fi

    # Test regex if set.
    if [ -n "$regex" ]; then
      echo "''${!name}" | ${pkgs.gnugrep}/bin/grep -e "$regex" &>/dev/null

      if [ $? -ne 0 ]; then
        if [ $print_status -eq 1 ]; then
          print_status_line --error "Environment variable \e[3;1m$name\e[0m did not match: $regex" 1>&2
        fi

        return 1
      fi
    fi

    if [ $print_status -eq 1 ]; then
      print_status_line --success "Environment variable \e[3;1m$name\e[0m is set"
    fi

    return 0
  }

  # Check if given file exists.
  #
  # @Arguments
  #   --cwd=<path>     Set the current working directory.
  #   --print-status   Print status line.
  #   <path>           Path to the file to check.
  #
  # @Returns
  #   0 if file exists, 1 otherwise.
  function check_file() {
    local path
    local print_status
    local cwd

    path=""
    print_status=0
    cwd=$(pwd)

    while [[ $# -gt 0 ]]; do
      case $1 in
        --cwd=*)
          cwd=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --print-status)
          print_status=1
          shift
          ;;
        *)
          path="$1"
          shift
          ;;
      esac
    done

    local relpath
    relpath=$(echo "$path" | sed "s#$cwd#.#")

    if [[ ! -f "$path" ]]; then
      if [ $print_status -eq 1 ]; then
        print_status_line --error "File \e[3;1m$relpath\e[0m does not exist" 1>&2
      fi

      return 1
    fi

    if [ $print_status -eq 1 ]; then
      print_status_line --success "File \e[3;1m$relpath\e[0m exists"
    fi

    return 0
  }

  # Prints given character to fill the whole line.
  #
  # The `max` columns will never be exceeded and the text
  # of --before and --after will be included within the
  # `max` column count.
  #
  # @Arguments
  #   --max=<number>    Line length in columns.
  #   --before=<text>   Text to print at begining.
  #   --after=<text>    Text to print at end.
  #   <char>            The character to print.
  function print_line_padded() {
    local max
    local char
    local insert_before
    local insert_after

    max=0
    char=""
    insert_before=""
    insert_after=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --max=*)
          max=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --before=*)
          insert_before=$(echo "$1" | cut -c 10-)
          shift
          ;;
        --after=*)
          insert_after=$(echo "$1" | cut -c 9-)
          shift
          ;;
        *)
          char="$1"
          shift
          ;;
      esac
    done

    local before_len
    local after_len

    before_len=$(get_str_len "$insert_before")
    after_len=$(get_str_len "$insert_after")

    # Calculate the effective line length
    # by subtracting the before and after strings.
    local eff_len
    eff_len=$((max - before_len - after_len))

    printf "$insert_before"

    for i in $(seq 1 "$eff_len"); do
      printf "$char"
    done;

    printf "$insert_after\n"
  }

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

  # Prints text on line and wrap words while not
  # exceeding max line length.
  #
  # The `max` columns will never be exceeded and the text
  # of --before and --after will be included within the
  # `max` column count.
  #
  # @Arguments
  #   --max=<number>    Line length in columns.
  #   --before=<text>   Text to print at begining.
  #   --after=<text>    Text to print at end.
  #   <text>            The text to print.
  function print_line_wrapped() {
    local max
    local text
    local insert_before
    local insert_after

    max=0
    text=""
    insert_before=""
    insert_after=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --max=*)
          max=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --before=*)
          insert_before=$(echo "$1" | cut -c 10-)
          shift
          ;;
        --after=*)
          insert_after=$(echo "$1" | cut -c 9-)
          shift
          ;;
        *)
          text="$1"
          shift
          ;;
      esac
    done

    local before_len
    local after_len
    before_len=$(get_str_len "$insert_before")
    after_len=$(get_str_len "$insert_after")

    # Calculate the effective line length
    # by subtracting the before and after strings.
    local eff_len
    eff_len=$((max - before_len - after_len))

    # Do the printing.
    local words
    local counter
    local lines
    words=$(printf "$text" | xargs -n1 echo)
    counter=0
    lines=1

    for word in $words; do
      if [ "$counter" -eq 0 ]; then
        printf "$insert_before"
      fi

      local word_len
      local new_len
      word_len=$(get_str_len "$word ")
      new_len=$((counter + word_len))

      if [ $new_len -le $eff_len ]; then
        printf "$word "
        counter=$new_len
      else
        local diff
        diff=$((eff_len - counter))

        for i in $(seq 1 $diff); do
          printf " "
        done

        printf "$insert_after\n"
        printf "$insert_before"
        printf "$word "

        counter=$word_len

        lines=$(( lines + 1 ))
      fi
    done

    local diff
    diff=$((eff_len - counter))

    for i in $(seq 1 $diff); do
      printf " "
    done
    printf "$insert_after\n"
  }

  # Prints an info/altert banner depending on type.
  #
  # @Arguments
  #   --title       The banner title text.
  #   --error       Print error banner.
  #   --warning     Print warning banner.
  #   --success     Print success banner.
  #   --info        Print info banner.
  #   <lines>       The lines to print as banner content.
  function print_banner() {
    local title
    local type
    local max_width
    local lines
    local old_ifs

    title=""
    type="error"
    max_width=100
    lines=()
    old_ifs=$IFS

    while [[ $# -gt 0 ]]; do
      case $1 in
        --title)
          title="$2"
          shift
          shift
          ;;
        --title=*)
          title=$(echo "$1" | cut -c 9-)
          shift
          ;;
        --error)
          type="error"
          shift
          ;;
        --warning)
          type="warning"
          shift
          ;;
        --success)
          type="success"
          shift
          ;;
        --info)
          type="info"
          shift
          ;;
        *)
          lines+=("$1")
          shift
          ;;
      esac
    done

    local cols
    cols=$(tput cols)
    if [ "$cols" -gt $max_width ]; then
      cols=$max_width
    fi

    # Top.
    print_line_padded --max="$cols" --before="\e[38;5;242m ┌" --after="┐ " "─"

    # Print title.
    if [ "$type" = "error" ]; then
      print_line_wrapped --max="$cols" --before="\e[38;5;242m │ \e[31m" --after="\e[38;5;242m │ " "\e[31m⚠ $title"
    elif [ "$type" = "warning" ]; then
      print_line_wrapped --max="$cols" --before="\e[38;5;242m │ \e[33m" --after="\e[38;5;242m │ " "\e[33m⚠ $title"
    elif [ "$type" = "success" ]; then
      print_line_wrapped --max="$cols" --before="\e[38;5;242m │ \e[32m" --after="\e[38;5;242m │ " "\e[32m✓ $title"
    else
      print_line_wrapped --max="$cols" --before="\e[38;5;242m │ \e[36m" --after="\e[38;5;242m │ " "\e[36m$title"
    fi

    # Blank
    print_line_padded --max="$cols" --before="\e[38;5;242m │" --after="\e[38;5;242m │ " " "

    IFS=:
    for line in "''${lines[@]}"; do
      IFS=$old_ifs

      if [ -z "$line" ]; then
        print_line_padded --max="$cols" --before="\e[38;5;242m │" --after="\e[38;5;242m │ " " "
      else
        print_line_wrapped --max="$cols" --before="\e[38;5;242m │ \e[0m" --after="\e[38;5;242m │ " "$line"
      fi
    done

    # Bottom.
    print_line_padded --max="$cols" --before="\e[38;5;242m └" --after="┘ " "─"

    # Reset ANSI.
    printf "\e[0m"
  }

  # Print text as figlet.
  #
  # @Arguments
  #   --prefix     Text to prepend before each line.
  #   <text>       Text to print as figlet.
  function print_figlet() {
    local prefix
    local text
    prefix=""
    text=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --prefix=*)
          prefix=$(echo "$1" | cut -c 10-)
          shift
          ;;
        *)
          text="$1"
          shift
          ;;
      esac
    done

    ${pkgs.figlet}/bin/figlet -f small "$text" |
      while IFS= read -r line; do
        echo -e "$prefix$line"
      done

    printf "\e[0m"
  }

  # Get devenv requirements.
  #
  # Loads the individual requirements from a
  # devenv.json file.
  #
  # @Arguments
  #   --cwd     The current working directory.
  #   --file    Name of the devenv file to load.
  #             Default: devenv.json
  #
  # @Returns
  #   Requirement items as base64.
  function get_devenv_requirements() {
    local cwd
    local file
    cwd=$(pwd)
    file="devenv.json"

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
        *)
          shift
          ;;
      esac
    done

    ${pkgs.jq}/bin/jq -r '.requirements.[] | @base64' < "$cwd/$file"
  }

  # Print devenv info.
  #
  # Loads info data from devenv file.
  #
  # @Arguments
  #   --cwd     The current working directory.
  #   --file    Name of the devenv file to load.
  #             Default: devenv.json
  function print_info() {
    local cwd
    local file
    cwd=$(pwd)
    file="devenv.json"

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
        *)
          shift
          ;;
      esac
    done

    # Read the info groups from json file.
    local groups
    groups=$(${pkgs.jq}/bin/jq -r '.info.groups.[] | @base64' < "$cwd/$file")

    # Print each group.
    for group in $groups; do
      group=$(echo "$group" | base64 --decode)

      # Extract name and items.
      local name
      local items
      name=$(echo "$group" | ${pkgs.jq}/bin/jq -r '.name')
      items=$(echo "$group" | ${pkgs.jq}/bin/jq -r '.items.[] | @base64')

      # Print header.
      echo -e " \e[36;1m$name:\e[0m"

      # Setup item counter.
      local length
      local i
      length=$(echo "$group" | ${pkgs.jq}/bin/jq '.items | length')
      i=1

      # Print each item.
      for item in $items; do
        item=$(echo "$item" | base64 --decode)

        # Extract name and description.
        local name
        local description
        name=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.name')
        description=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.description')

        # Determine symbol.
        local symbol
        symbol="├"
        # If last item, use other symbol.
        if [ $i -eq "$length" ]; then
          symbol="└"
        fi

        # Print item.
        printf "   $symbol $name"

        # Append optional description.
        if [ "$description" != "null" ]; then
          printf " \e[38;5;242m# $description\e[0m"
        fi

        # End with newline.
        printf "\n"

        i=$(( i + 1))
      done

      # Spacing.
      echo
    done
  }

  # Prompt user value.
  #
  # Prompts the user to input a value.
  #
  # @Arguments
  #   --name         The name of what to prompt for.
  #   --description  Optional description to display.
  #   --link         Optional link to display.
  #   --regex        Optional regex to validate value.
  function prompt_user_value() {
    local name
    local description
    local link
    local regex

    name=""
    description=""
    link=""
    regex=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --name=*)
          name=$(echo "$1" | cut -c 8-)
          shift
          ;;
        --description=*)
          description=$(echo "$1" | cut -c 15-)
          shift
          ;;
        --link=*)
          link=$(echo "$1" | cut -c 8-)
          shift
          ;;
        --regex=*)
          regex=$(echo "$1" | cut -c 9-)
          shift
          ;;
        *)
          shift
          ;;
      esac
    done

    >&2 echo -e " Enter value for: \e[3;1m$name\e[0m"
    if [ -n "$description" ]; then
      symbol="└"
      if [ -n "$link" ]; then
        symbol="├"
      fi
      >&2 echo -e "   \e[38;5;242m$symbol $description\e[0m"
    fi
    if [ -n "$link" ]; then
      >&2 echo -e "   \e[38;5;242m└ Link: $link\e[0m"
    fi
    >&2 echo

    local input
    local valid
    input=""
    valid=0

    while [ -z "$input" ] || [ $valid -eq 0 ]; do
      read -r -p "   Value: " input


      if [ -n "$regex" ]; then
        echo "$input" | ${pkgs.gnugrep}/bin/grep -e "$regex" &>/dev/null

        if [ $? -ne 0 ]; then
          >&2 echo -e "     \e[31mInput did not match $regex!\e[0m"
        else
          valid=1
        fi
      else
        valid=1
      fi
    done

    echo "$input"
  }

  # Checks all requirements.
  #
  # Loads all requirements from the devenv file and
  # prints status info.
  # Success messages are printed to stdout and errors to
  # stderr.
  #
  # @Arguments
  #   --cwd=<path>          The current working directory.
  #   --devenv-file=<file>  Name of the devenv file to load.
  #                         Default: devenv.json
  function check_requirements() {
    local cwd
    local devenv_file
    cwd=$(pwd)
    devenv_file="devenv.json"

    while [[ $# -gt 0 ]]; do
      case $1 in
        --cwd=*)
          cwd=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --devenv-file=*)
          devenv_file=$(echo "$1" | cut -c 15-)
          shift
          ;;
        *)
          shift
          ;;
      esac
    done

    load_env_files --cwd="$cwd"
    if [ $? -ne 0 ]; then
      print_banner \
        --warning \
        --title="No env files found!" \
        "Neither a .env nor a .env.local file could be found in project root folder." \
        "" \
        "\e[36mPlease type \`setup\` to start the setup wizard."
      echo
    fi

    local reqs
    local success
    reqs=$(get_devenv_requirements --cwd="$cwd" --file="$devenv_file")
    success=1

    for req in $reqs; do
      req=$(echo "$req" | base64 --decode)

      local type
      type=$(echo "$req" | ${pkgs.jq}/bin/jq -r .type)

      case "$type" in
        env)
          local name
          local regex
          name=$(echo "$req" | ${pkgs.jq}/bin/jq -r .name)
          regex=$(echo "$req" | ${pkgs.jq}/bin/jq -r .regex)

          if [ "$regex" = "null" ]; then
            regex=""
          fi

          check_env_var --print-status --regex="$regex" "$name"
          if [ $? -ne 0 ]; then
            success=0
          fi
          ;;
        file)
          local path
          path=$(echo "$req" | ${pkgs.jq}/bin/jq -r .path)

          check_file --print-status "$path"
          if [ $? -ne 0 ]; then
            success=0
          fi
          ;;
      esac
    done

    if [ $success -eq 1 ]; then
      return 0
    fi

    return 1
  }

  # Runs startup check.
  #
  # Silently runs the requirements check and prints only
  # errors. If there are errors, print a message box to inform
  # the user to run the setup command.
  #
  # @Arguments
  #   --cwd=<path>          The current working directory.
  #   --title=<text>        Title to print as figlet.
  #   --devenv-file=<file>  Name of the devenv file to load.
  #                         Default: devenv.json
  function startup_check() {
    local title
    local cwd
    local devenv_file

    title=""
    cwd=$(pwd)
    devenv_file="devenv.json"

    while [[ $# -gt 0 ]]; do
      case $1 in
        --cwd=*)
          cwd=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --title=*)
          title=$(echo "$1" | cut -c 9-)
          shift
          ;;
        --devenv-file=*)
          devenv_file=$(echo "$1" | cut -c 15-)
          shift
          ;;
        *)
          shift
          ;;
      esac
    done

    print_figlet "$title" --prefix="\e[1;32m  "

    check_requirements --cwd="$cwd" --devenv-file="$devenv_file" >/dev/null

    if [ $? -ne 0 ]; then
      echo

      print_banner \
        --error \
        --title="Devenv not functional" \
        "The development environment is not yet fully functional." \
        "" \
        "\e[36mPlease type \`setup\` to start the setup wizard to add missing requirements."

      return 1
    fi

    return 0
  }

  # Starts the setup wizard.
  #
  # Checks all requirements in the devenv file and
  # prompts the user to input a value or run specified
  # commands to create files or env vars.
  #
  # @Arguments
  #   --cwd=<path>          The current working directory.
  #   --env-file=<file>     Name of the .env file to write to.
  #                         Default: .env.local
  #   --devenv-file=<file>  Name of the devenv file to load.
  #                         Default: devenv.json
  function setup_wizard() {
    local cwd
    local env_file
    local devenv_file

    cwd=$(pwd)
    env_file=".env.local"
    devenv_file="devenv.json"

    while [[ $# -gt 0 ]]; do
      case $1 in
        --cwd=*)
          cwd=$(echo "$1" | cut -c 7-)
          shift
          ;;
        --env-file=*)
          env_file=$(echo "$1" | cut -c 12-)
          shift
          ;;
        --devenv-file=*)
          devenv_file=$(echo "$1" | cut -c 15-)
          shift
          ;;
        *)
          shift
          ;;
      esac
    done

    print_banner \
      --info \
      --title="Interactive Setup Wizard" \
      "This wizard will help you set up the development environment."

    load_env_files --cwd="$cwd" --verbose

    echo

    local reqs
    reqs=$(get_devenv_requirements --cwd="$cwd" --file="$devenv_file")

    for req in $reqs; do
      req=$(echo "$req" | base64 --decode)

      local type
      local command
      type=$(echo "$req" | ${pkgs.jq}/bin/jq -r .type)
      command=$(echo "$req" | ${pkgs.jq}/bin/jq -r .command)

      if [ "$command" = "null" ]; then
        command=""
      fi

      case "$type" in
        env)
          local name
          local description
          local link
          local regex

          name=$(echo "$req" | ${pkgs.jq}/bin/jq -r .name)
          description=$(echo "$req" | ${pkgs.jq}/bin/jq -r .description)
          link=$(echo "$req" | ${pkgs.jq}/bin/jq -r .link)
          regex=$(echo "$req" | ${pkgs.jq}/bin/jq -r .regex)

          if [ "$description" = "null" ]; then
            description=""
          fi
          if [ "$link" = "null" ]; then
            link=""
          fi
          if [ "$regex" = "null" ]; then
            regex=""
          fi
          if [ -n "$command" ]; then
            command=$(echo "$command" | ${pkgs.gnused}/bin/sed "s|#name#|$name|g" | ${pkgs.gnused}/bin/sed "s|#regex#|$regex|g")
          fi

          check_env_var --print-status --regex="$regex" "$name" >/dev/null

          if [ $? -ne 0 ]; then
            echo

            if [ -n "$command" ]; then
              command=$(echo "$command" | ${pkgs.gnused}/bin/sed "s|#path#|$path|g" | ${pkgs.gnused}/bin/sed "s|#abs_path#|$abspath|g")

              echo -e "\e[38;5;242m   🛈 Generating env var from command: $command\e[0m"

              local val
              val=$($command 2> >(while read -r line; do >&2 printf "     \e[38;5;242m> \e[0m$line\n"; done))

              write_to_env_file --file="$env_file" --cwd="$cwd" --name="$name" "$val"
            else
              local val
              val=$(prompt_user_value --name="$name" --description="$description" --link="$link" --regex="$regex")

              write_to_env_file --file="$env_file" --cwd="$cwd" --name="$name" "$val"
            fi

            echo
          fi
          ;;
        file)
          local path
          local abspath
          local description

          path=$(echo "$req" | ${pkgs.jq}/bin/jq -r .path)
          abspath="$path"
          description=$(echo "$req" | ${pkgs.jq}/bin/jq -r .description)

          if [ "$(echo "$path" | cut -c1)" != "/" ]; then
            abspath=$(readlink -f "$cwd/$path")
          fi
          if [ "$description" = "null" ]; then
            description=""
          fi

          check_file --print-status --cwd="$cwd" "$path" >/dev/null

          if [ $? -ne 0 ]; then
            echo

            if [ -n "$command" ]; then
              command=$(echo "$command" | ${pkgs.gnused}/bin/sed "s|#path#|$path|g" | ${pkgs.gnused}/bin/sed "s|#abs_path#|$abspath|g")

              echo -e "\e[38;5;242m   🛈 Generating file from command: $command\e[0m"

              $command 2>&1 | while read -r line; do printf "     \e[38;5;242m> \e[0m$line\n"; done
            else
              echo -e "\e[33m   🛈 Please manually create the file at: $path\e[0m"
              if [ -n "$description" ]; then
                symbol="└"
                if [ -n "$link" ]; then
                  symbol="├"
                fi
                echo -e "   \e[38;5;242m$symbol $description\e[0m"
              fi
              if [ -n "$link" ]; then
                echo -e "   \e[38;5;242m└ Link: $link\e[0m"
              fi
            fi

            echo
          fi
          ;;
      esac
    done

    echo

    local cols
    cols=$(tput cols)
    if [ "$cols" -gt 100 ]; then
      cols=100
    fi

    print_line_padded --max="$cols" --before="\e[38;5;242m " --after="\e[0m " "─"

    echo
    echo -e " 🛈 Running requirements check..."
    echo

    check_requirements --cwd="$cwd" --devenv-file="$devenv_file"

    if [ $? -eq 0 ]; then
      echo

      print_banner \
        --success \
        --title="Setup complete" \
        "Please exit an re-enter the dev shell for changes to take effect!"
    else
      echo

      print_banner \
        --warning \
        --title="Setup non-successful" \
        "The requirements check did not succeed!" \
        "" \
        "Please re-run setup and check logs for any problems."
    fi
  }
''
