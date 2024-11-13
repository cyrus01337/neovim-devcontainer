FROM cyrus01337/shell-devcontainer:latest AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
ENV TERM="tmux-256color"
ENV HELPFUL_PACKAGES="iproute2"
ENV TRANSIENT_PACKAGES="build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev xz-utils"
USER root

RUN nala update \
    && nala install -y --no-install-recommends --no-install-suggests black fd-find gcc git isort jq lua5.1 luarocks make php-cli ripgrep unzip \
    $HELPFUL_PACKAGES \
    $TRANSIENT_PACKAGES \
    && nala autoremove -y \
    && nala clean \
    && rm -rf /var/lib/apt/lists/* \
    \
    && usermod -aG docker $USER;

FROM system AS composer
USER root

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

FROM system AS python
ENV PATH="$HOME/.pyenv/bin:$PATH"
USER $USER
WORKDIR $HOME

RUN curl https://pyenv.run | bash \
    && eval "$(pyenv init -)" \
    && eval "$(pyenv virtualenv-init -)";
RUN pyenv install 3.11 \
    && pyenv virtualenv 3.11 home;

FROM system AS stylua
USER root
WORKDIR /usr/bin

RUN curl -fsLS https://github.com/JohnnyMorganz/StyLua/releases/download/v0.20.0/stylua-linux-x86_64.zip -o stylua.zip \
    && unzip stylua.zip \
    && rm stylua.zip;

FROM system AS zig
USER root
ENV UNPACKED_DIRECTORY_NAME="zig-linux-x86_64-0.14.0-dev.2238+1db8cade5"
WORKDIR /tmp

RUN curl -L "https://ziglang.org/builds/${UNPACKED_DIRECTORY_NAME}.tar.xz" \
    | tar -Jx "${UNPACKED_DIRECTORY_NAME}/lib/" "${UNPACKED_DIRECTORY_NAME}/zig";

WORKDIR /zig

RUN mv /tmp/${UNPACKED_DIRECTORY_NAME}/* . \
    && rm -rf "/tmp/${UNPACKED_DIRECTORY_NAME}";

FROM system AS cleanup
USER root

COPY --chown=$USER:$GROUP ./configuration/ $HOME/.config/nvim/
COPY --from=composer /usr/local/bin/composer /usr/local/bin/composer
COPY --from=dive /usr/bin/dive /usr/bin/dive
COPY --from=go /go/ /usr/local/
COPY --from=neovim /neovim/ /usr/
COPY --from=stylua /usr/bin/stylua /usr/bin/stylua
COPY --from=zig /zig/lib/ /usr/lib/zig/
COPY --from=zig /zig/zig /usr/bin/zig

# This takes a while so we're leaving this at the end
COPY --from=node --chown=$USER:$GROUP $HOME/.local/share/fnm/ $HOME/.local/share/fnm/
COPY --from=python --chown=$USER:$GROUP $HOME/.pyenv $HOME/.pyenv

RUN nala remove -y $TRANSIENT_PACKAGES \
    && rm -rf /var/lib/apt/lists/* \
    && nala clean \
    && nala autoremove -y;

FROM cleanup AS final
USER $USER
WORKDIR /workspace

RUN touch $HOME/.gitconfig $HOME/.git-credentials \
    && mkdir -p $HOME/.local/share/nvim;
