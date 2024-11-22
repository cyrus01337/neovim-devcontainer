FROM cyrus01337/shell-devcontainer:latest AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
ENV TERM="tmux-256color"
ENV HELPFUL_PACKAGES="iproute2 jq less openssh-client"
ENV TRANSIENT_PACKAGES="curl"
USER root

RUN nala update \
    && nala install -y --no-install-recommends --no-install-suggests fd-find gcc lua5.1 luarocks make php-cli ripgrep \
    $HELPFUL_PACKAGES \
    $TRANSIENT_PACKAGES \
    && nala autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    \
    && usermod -aG docker $USER;

FROM debian:bookworm-slim AS composer
USER root

RUN apt-get update \
    && apt-get install -y curl php-cli \
    && rm -rf /var/lib/apt/lists/*;
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin/ --filename=composer \
    && rm composer-setup.php;

FROM system AS dive
USER root

COPY ./install-dive.sh .

RUN ./install-dive.sh \
    && rm ./install-dive.sh;

FROM system AS go
USER $USER
WORKDIR /go

RUN curl -fsLS https://go.dev/dl/go1.23.1.linux-amd64.tar.gz -o go.tar.gz \
    && tar xfz go.tar.gz \
    && rm go.tar.gz;

FROM system AS neovim
USER root
WORKDIR /neovim

RUN curl -fsLS https://github.com/neovim/neovim/releases/download/v0.10.1/nvim-linux64.tar.gz -o neovim.tar.gz \
    && tar xfz neovim.tar.gz --strip-components=1 \
    && rm neovim.tar.gz;

FROM system AS node
USER $USER

RUN curl -fsLS https://fnm.vercel.app/install | bash -s -- --skip-shell --install-dir "$HOME/.local/share/fnm";

ENV PATH="$HOME/.local/share/fnm:$PATH"

RUN eval "$(fnm env --shell bash)" \
    && fnm use --install-if-missing 22 \
    && npm install -g live-server npm prettier;

FROM debian:bookworm-slim AS python
ENV PATH="/root/.pyenv/bin:/root/.local/pyenv/shims:$PATH"
USER root
WORKDIR /root/

RUN apt-get update \
    && apt-get install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
    && rm -rf /var/lib/apt/lists/*;

COPY install-pyenv.sh .

RUN ./install-pyenv.sh \
    && rm install-pyenv.sh;

FROM debian:bookworm-slim AS stylua
USER root
WORKDIR /usr/bin

RUN apt-get update \
    && apt-get install -y curl unzip \
    && rm -rf /var/lib/apt/lists/*;
RUN curl -fsLS https://github.com/JohnnyMorganz/StyLua/releases/download/v0.20.0/stylua-linux-x86_64.zip -o stylua.zip \
    && unzip stylua.zip \
    && rm stylua.zip;

FROM system AS cleanup
USER root

COPY --chown=$USER:$GROUP ./configuration/ $HOME/.config/nvim/
COPY --from=composer /usr/local/bin/composer /usr/local/bin/composer
COPY --from=dive /usr/bin/dive /usr/bin/dive
COPY --from=go /go/ /usr/local/
COPY --from=neovim /neovim/ /usr/
COPY --from=stylua /usr/bin/stylua /usr/bin/stylua

# This takes a while so we're leaving this at the end
COPY --from=node --chown=$USER:$GROUP $HOME/.local/share/fnm/ $HOME/.local/share/fnm/
COPY --from=python --chown=$USER:$GROUP /root/.pyenv $HOME/.pyenv

RUN nala remove -y $TRANSIENT_PACKAGES \
    && nala autoremove -y \
    && rm -rf /var/lib/apt/lists/*;

FROM cleanup AS final
USER $USER
WORKDIR /workspace

RUN touch $HOME/.gitconfig $HOME/.git-credentials \
    && mkdir -p $HOME/.local/share/nvim;
