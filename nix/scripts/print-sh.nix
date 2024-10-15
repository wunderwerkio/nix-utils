{
  pkgs,
  utils-sh,
  ...
}:
pkgs.writeShellScript "print.sh" ''
  source ${utils-sh}

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
''
