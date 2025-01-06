FROM cyrus01337/shell-devcontainer:latest AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
ENV TERM="tmux-256color"
ENV HELPFUL_PACKAGES="iproute2 jq less parallel"
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests fd-find gcc gnupg2 lua5.1 locales locales-all luarocks make php-cli ripgrep \
    && apt-get install -y $HELPFUL_PACKAGES \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    \
    && usermod -aG docker $USER;

FROM system AS bun
USER $USER
ENV BUN_INSTALL="$HOME/.bun"

RUN curl -fsSL https://bun.sh/install | bash;

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

FROM system AS lazydocker
USER root
WORKDIR /lazydocker

RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash \
    && mv ~/.local/bin/lazydocker .;

FROM system AS lazygit
USER root
WORKDIR /lazygit

RUN curl -fsLS https://github.com/jesseduffield/lazygit/releases/download/v0.44.1/lazygit_0.44.1_Linux_x86_64.tar.gz \
    | tar xz;

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
ENV LC_ALL="en_GB.UTF-8"
ENV LANG="en_GB.UTF-8"
ENV LANGUAGE="en_GB.UTF-8"
USER root

COPY --from=bun /home/developer/.bun /home/developer/.bun
COPY --from=composer /usr/local/bin/composer /usr/local/bin/composer
COPY --from=dive /usr/bin/dive /usr/bin/dive
COPY --from=go /go/ /usr/local/
COPY --from=lazydocker /lazydocker/lazydocker /usr/local/bin/lazydocker
COPY --from=lazygit /lazygit/lazygit /usr/local/bin/lazygit
COPY --from=neovim /neovim/ /usr/
COPY --from=stylua /usr/bin/stylua /usr/bin/stylua

# Result of long-standing operations from shortest time taken - longest in
# ascending order
COPY --from=node --chown=$USER:$GROUP $HOME/.local/share/fnm/ $HOME/.local/share/fnm/
COPY --from=python --chown=$USER:$GROUP /root/.pyenv $HOME/.pyenv

RUN apt-get remove -y $TRANSIENT_PACKAGES \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*;

FROM cleanup AS final
USER $USER
WORKDIR $HOME
