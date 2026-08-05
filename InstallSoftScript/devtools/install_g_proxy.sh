#!/usr/bin/env bash
set -e

# 镜像加速
proxy="https://gh-proxy.com/"

function get_arch() {
    a=$(uname -m)
    case ${a} in
    "x86_64" | "amd64")
        echo "amd64"
        ;;
    "i386" | "i486" | "i586")
        echo "386"
        ;;
    "aarch64" | "arm64")
        echo "arm64"
        ;;
    "armv6l" | "armv7l")
        echo "arm"
        ;;
    "s390x")
        echo "s390x"
        ;;
    "riscv64")
        echo "riscv64"
        ;;
    *)
        echo ${NIL}
        ;;
    esac
}

function get_os() {
    echo $(uname -s | awk '{print tolower($0)}')
}

# Setup shell configuration for bash/zsh (POSIX-compatible shells)
function setup_posix_shell() {
    local rc_file=$1
    cat >>"${rc_file}" <<'EOF'

[ -s "${HOME}/.g/env" ] && \. "${HOME}/.g/env"  # g shell setup
EOF
}

# Setup shell configuration for csh/tcsh
function setup_csh_shell() {
    local rc_file=$1
    cat >>"${rc_file}" <<'EOF'
setenv GOROOT "$HOME/.g/go"

if ( ! $?GOPATH ) then
    setenv GOPATH "$HOME/go"
else if ( "$GOPATH" == "" ) then
    setenv GOPATH "$HOME/go"
endif

setenv PATH "$HOME/.g/bin:$GOROOT/bin:$GOPATH/bin:$PATH"
setenv G_MIRROR "https://golang.google.cn/dl/"
EOF
}

# Setup shell configuration for fish
function setup_fish_shell() {
    # Create fish-specific env file
    cat >"${HOME}/.g/env.fish" <<'EOF'
# g shell setup for fish

set -gx GOROOT "$HOME/.g/go"
set -gx G_MIRROR "https://golang.google.cn/dl/"

# Add g, GOROOT/bin, and GOPATH/bin (if set) to PATH using fish_add_path
fish_add_path "$HOME/.g/bin"
fish_add_path "$GOROOT/bin"

# Set GOPATH only if not already set or empty (consistent with bash/zsh/csh behavior)
if not set -q GOPATH; or test -z "$GOPATH"
    set -gx GOPATH "$HOME/go"
end

if set -q GOPATH
    fish_add_path "$GOPATH/bin"
end
EOF

    # Configure fish to source env.fish
    local fish_conf_d_dir="${HOME}/.config/fish/conf.d"
    mkdir -p "${fish_conf_d_dir}"
    cat >"${fish_conf_d_dir}/g.fish" <<'EOF'
# g shell setup
if test -s "$HOME/.g/env.fish"; and source "$HOME/.g/env.fish"; end
EOF
}

# Configure all available shells
function configure_shells() {
    # POSIX-compatible shells (bash, zsh)
    if [ -x "$(command -v bash)" ]; then
        setup_posix_shell "${HOME}/.bashrc"
    fi

    if [ -x "$(command -v zsh)" ]; then
        setup_posix_shell "${HOME}/.zshrc"
    fi

    # Fish shell
    if [ -x "$(command -v fish)" ]; then
        setup_fish_shell
    fi

    # C shell variants
    if [ -x "$(command -v csh)" ]; then
        setup_csh_shell "${HOME}/.cshrc"
    fi

    if [ -x "$(command -v tcsh)" ]; then
        setup_csh_shell "${HOME}/.tcshrc"
    fi
}

function main() {
    local release="1.8.0"
    local os=$(get_os)
    local arch=$(get_arch)
    local dest_file="${HOME}/.g/downloads/g${release}.${os}-${arch}.tar.gz"
    local url="${proxy}https://github.com/voidint/g/releases/download/v${release}/g${release}.${os}-${arch}.tar.gz"

    echo "[1/3] Downloading ${url}"
    rm -f "${dest_file}"
    if [ -x "$(command -v wget)" ]; then
        mkdir -p "${HOME}/.g/downloads"
        wget -q -P "${HOME}/.g/downloads" "${url}"
    else
        curl -s -S -L --create-dirs -o "${dest_file}" "${url}"
    fi

    echo "[2/3] Install g to the ${HOME}/.g/bin"
    mkdir -p "${HOME}/.g/bin"
    tar -xz -f "${dest_file}" -C "${HOME}/.g/bin"
    chmod +x "${HOME}/.g/bin/g"

    echo "[3/3] Set environment variables"
    cat >"${HOME}/.g/env" <<'EOF'
#!/bin/sh
# g shell setup
export GOROOT="${HOME}/.g/go"
[ -z "$GOPATH" ] && export GOPATH="${HOME}/go"
export PATH="${HOME}/.g/bin:${GOROOT}/bin:${GOPATH}/bin:$PATH"
export G_MIRROR=https://golang.google.cn/dl/
EOF

    configure_shells

    echo -e "\nTo configure your current shell, run:\nsource \"$HOME/.g/env\""

    exit 0
}

main
