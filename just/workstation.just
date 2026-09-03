set unstable := true
set quiet := true
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

resources_dir := justfile_directory() / 'just' / 'resources'

platform := ```
    case "$(uname -s)" in
      Darwin*) echo "darwin" ;;
      Linux*) echo "linux" ;;
      MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
      *) echo "unknown" ;;
    esac
```

[private]
default:
    just --list workstation

[doc('Set up development environment based on platform')]
setup:
    just workstation setup-{{ platform }}

[doc('Set up macOS development environment')]
setup-darwin: brew krew

[doc('Set up Linux development environment')]
setup-linux: brew-install brew krew

[doc('Set up Windows development environment via WSL')]
setup-windows:
    echo "Please run this recipe from within WSL"
    just workstation setup-linux

[doc('Install Homebrew on Linux')]
[script]
brew-install:
    if command -v brew &>/dev/null; then
        echo "Homebrew already installed"
        exit 0
    fi
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

[doc('Set up Homebrew tools')]
[script]
brew skip_existing='false':
    just require brew
    test -f "{{ resources_dir }}/Brewfile"
    if [[ "{{ skip_existing }}" == "true" ]]; then
        brew bundle --file "{{ resources_dir }}/Brewfile" --no-upgrade
    else
        brew bundle --file "{{ resources_dir }}/Brewfile"
    fi

[doc('Set up Krew tools')]
krew: brew
    just require kubectl
    kubectl krew version
    kubectl krew install cert-manager cnpg browse-pvc node-shell rook-ceph view-secret

# Ported verbatim from .taskfiles/workstation/Taskfile.yaml. Task ran this
# without errexit, and several of the probes below deliberately return
# non-zero, so errexit is disabled to keep the original behaviour.
[doc('Check installed tools from Brewfile and Krew plugins')]
[script]
check-tools:
    set +e
    echo "Checking tools from Brewfile..."

    # Extract taps, brews and casks from Brewfile
    TAPS=$(grep -E '^tap "' "{{ resources_dir }}/Brewfile" | sed 's/tap "//g' | sed 's/"//g')
    BREW_TOOLS=$(grep -E '^brew "' "{{ resources_dir }}/Brewfile" | sed 's/brew "//g' | sed 's/"//g')
    CASK_TOOLS=$(grep -E '^cask "' "{{ resources_dir }}/Brewfile" | sed 's/cask "//g' | sed 's/"//g')

    # Define Krew plugins to check
    KREW_PLUGINS="cert-manager cnpg browse-pvc node-shell rook-ceph view-secret"

    # Display taps
    echo "Homebrew Taps:"
    for tap in $TAPS; do
      if brew tap | grep -q "$tap"; then
        echo "ok      $tap (tapped)"
      else
        echo "missing $tap (not tapped)"
      fi
    done
    echo ""

    # Function to extract actual command name from brew formula
    get_command_name() {
      local formula=$1
      # Handle special cases where formula name != command name
      case "$formula" in
        "fluxcd/tap/flux") echo "flux" ;;
        "go-task/tap/go-task") echo "task" ;;
        "siderolabs/tap/talosctl") echo "talosctl" ;;
        "kubernetes-cli") echo "kubectl" ;;
        *)
          # For other formulas, extract the last part after the last /
          echo "$formula" | sed 's|.*/||'
          ;;
      esac
    }

    # Function to get version based on tool-specific commands
    get_version() {
      local tool=$1
      case "$tool" in
        kubectl)
          $tool version --client --short 2>/dev/null || $tool version --client 2>/dev/null || echo "Version check failed"
          ;;
        talosctl)
          $tool version --short 2>/dev/null || $tool version 2>/dev/null || echo "Version check failed"
          ;;
        k9s)
          # Extract just the version line from k9s output
          $tool version 2>/dev/null | grep "Version:" | sed 's/Version:[[:space:]]*//' || echo "Version check failed"
          ;;
        helm)
          $tool version --short 2>/dev/null || $tool version 2>/dev/null || echo "Version check failed"
          ;;
        flux)
          $tool --version 2>/dev/null || echo "Version check failed"
          ;;
        task|just)
          $tool --version 2>/dev/null || echo "Version check failed"
          ;;
        *)
          $tool --version 2>/dev/null || $tool version 2>/dev/null || $tool -v 2>/dev/null || echo "Version check failed"
          ;;
      esac
    }

    # Display brew tools
    echo "Homebrew Packages:"
    echo "Package | Command | Status | Version | Path"
    echo "--------|---------|--------|---------|-----"
    for formula in $BREW_TOOLS; do
      cmd=$(get_command_name "$formula")
      echo -n "$formula | $cmd | "
      if command -v $cmd &> /dev/null; then
        path=$(which $cmd)
        # Get version using the custom function
        version_output=$(get_version "$cmd")
        version=$(echo "$version_output" | head -n 1)
        echo "Installed | $version | $path"
      else
        echo "Missing | - | -"
      fi
    done
    echo ""

    # Check cask tools (macOS only)
    if [ "{{ platform }}" = "darwin" ]; then
      echo "Homebrew Casks:"
      echo "Cask | Status | Location"
      echo "-----|--------|--------"
      for cask in $CASK_TOOLS; do
        echo -n "$cask | "
        if [ -d "/Applications/$cask.app" ]; then
          echo "Installed | /Applications/$cask.app"
        elif [ -d "/Applications/$cask" ]; then
          echo "Installed | /Applications/$cask"
        elif command -v $cask &> /dev/null; then
          path=$(which $cask)
          echo "Installed | $path"
        else
          echo "Missing | -"
        fi
      done
      echo ""
    fi

    # Check Krew plugins
    if command -v kubectl &> /dev/null; then
      echo "Kubectl Krew Plugins:"
      echo "Plugin | Status | Version"
      echo "-------|--------|--------"

      # Get list of installed plugins
      if kubectl krew list &>/dev/null; then
        INSTALLED_PLUGINS=$(kubectl krew list 2>/dev/null | tail -n +2 | awk '{print $1}')
      else
        INSTALLED_PLUGINS=""
      fi

      for plugin in $KREW_PLUGINS; do
        # Special handling for browse-pvc which might have a different binary name
        if [ "$plugin" = "browse-pvc" ] && [ -f "${KREW_ROOT:-$HOME/.krew}/bin/kubectl-browse_pvc" ]; then
          echo "browse-pvc | Installed | -"
          continue
        fi

        echo -n "$plugin | "
        if echo "$INSTALLED_PLUGINS" | grep -q "^$plugin$"; then
          echo -n "Installed | "

          # Special handling for plugins with unique version commands
          case "$plugin" in
            rook-ceph)
              # rook-ceph doesn't support version flags
              echo "Plugin detected"
              ;;
            cert-manager)
              # cert-manager has a specific version command format
              VERSION_OUTPUT=$(timeout 2s kubectl cert-manager version 2>/dev/null || echo "-")
              echo "$VERSION_OUTPUT" | head -n 1
              ;;
            *)
              # Default version check for other plugins
              VERSION_OUTPUT=$(timeout 2s kubectl $plugin --version 2>/dev/null || timeout 2s kubectl $plugin version 2>/dev/null || echo "-")
              echo "$VERSION_OUTPUT" | head -n 1
              ;;
          esac
        else
          echo "Missing | -"
        fi
      done
      echo ""
    else
      echo "Kubectl not installed, skipping Krew plugins check."
      echo ""
    fi

    # Summary
    BREW_COUNT=$(echo "$BREW_TOOLS" | wc -w | tr -d ' ')
    BREW_INSTALLED=$(echo "$BREW_TOOLS" | tr ' ' '\n' | while read formula; do
      cmd=$(get_command_name "$formula")
      command -v $cmd &>/dev/null && echo $formula
    done | wc -l | tr -d ' ')

    echo "Summary:"
    echo "- Taps: $(echo "$TAPS" | wc -w | tr -d ' ')"
    echo "- Brew packages: $BREW_INSTALLED of $BREW_COUNT installed"

    if [ "{{ platform }}" = "darwin" ]; then
      CASK_COUNT=$(echo "$CASK_TOOLS" | wc -w | tr -d ' ')
      CASK_INSTALLED=$(echo "$CASK_TOOLS" | tr ' ' '\n' | while read cask; do
        [ -d "/Applications/$cask.app" ] || [ -d "/Applications/$cask" ] || command -v $cask &>/dev/null && echo $cask
      done | wc -l | tr -d ' ')
      echo "- Cask applications: $CASK_INSTALLED of $CASK_COUNT installed"
    fi

    if command -v kubectl &> /dev/null && kubectl krew version &> /dev/null; then
      KREW_COUNT=$(echo "$KREW_PLUGINS" | wc -w | tr -d ' ')

      # More robust way to count installed plugins
      KREW_INSTALLED=0
      for plugin in $KREW_PLUGINS; do
        if kubectl krew list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -q "^$plugin$"; then
          KREW_INSTALLED=$((KREW_INSTALLED + 1))
        elif [ "$plugin" = "browse-pvc" ] && [ -f "${KREW_ROOT:-$HOME/.krew}/bin/kubectl-browse_pvc" ]; then
          KREW_INSTALLED=$((KREW_INSTALLED + 1))
        fi
      done

      echo "- Krew plugins: $KREW_INSTALLED of $KREW_COUNT installed"
    fi
