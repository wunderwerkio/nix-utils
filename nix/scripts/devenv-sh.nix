{
  pkgs,
  env-sh,
  print-sh,
  ...
}:
pkgs.writeShellScript "devenv.sh" ''
  #
  # DevEnv Helper Script.
  #
  # This script provides several functions to build
  # individual devenv scripts.
  #

  source ${env-sh}
  source ${print-sh}

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
    setup_cmd="setup"

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
        --setup-cmd=*)
          setup_cmd=$(echo "$1" | cut -c 13-)
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
        "\e[36mPlease type \`$setup_cmd\` to start the setup wizard."
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
    local setup_cmd

    title=""
    cwd=$(pwd)
    devenv_file="devenv.json"
    setup_cmd="setup"

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
        --setup-cmd=*)
          setup_cmd=$(echo "$1" | cut -c 13-)
          shift
          ;;
        *)
          shift
          ;;
      esac
    done

    print_figlet "$title" --prefix="\e[1;32m  "

    check_requirements --cwd="$cwd" --devenv-file="$devenv_file" --setup-cmd="$setup_cmd" >/dev/null

    if [ $? -ne 0 ]; then
      echo

      print_banner \
        --error \
        --title="Devenv not functional" \
        "The development environment is not yet fully functional." \
        "" \
        "\e[36mPlease type \`$setup_cmd\` to start the setup wizard to add missing requirements."

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
