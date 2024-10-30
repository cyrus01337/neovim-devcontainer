FROM cyrus01337/shell-devcontainer AS system
ENV DEBIAN_FRONTEND="noninteractive"
ENV USER="developer"
ENV GROUP="$USER"
ENV HOME="/home/$USER"
ENV TERM="tmux-256color"
USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends --no-install-suggests black fd-find gcc git isort jq lua5.1 luarocks make php-cli python3.11-venv python3-pip ripgrep unzip \
    iproute2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 20 \
    \
    && addgroup docker \
    && usermod -aG docker $USER;

FROM system AS composer
USER root

RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin/ --filename=composer \
    && rm composer-setup.php;

FROM system AS delta
USER root

RUN curl https://api.github.com/repos/dandavison/delta/releases/latest \
    | jq -r ".assets[9].browser_download_url" \
    | xargs -r -I{} curl -L "{}" -o delta.deb \
    && dpkg -i delta.deb \
    && rm delta.deb;

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
USER $USER

RUN python -m pip install -U pip;

FROM system AS stylua
USER root
WORKDIR /usr/bin

RUN curl -fsLS https://github.com/JohnnyMorganz/StyLua/releases/download/v0.20.0/stylua-linux-x86_64.zip -o stylua.zip \
    && unzip stylua.zip \
    && rm stylua.zip;

FROM system AS cleanup
USER root

COPY --chown=$USER:$GROUP ./configuration/ $HOME/.config/nvim/
COPY --from=composer /usr/local/bin/composer /usr/local/bin/composer
COPY --from=delta /usr/bin/delta /usr/bin/delta
COPY --from=delta /usr/share/doc/git-delta/ /usr/share/doc/git-delta/
COPY --from=delta /var/lib/dpkg/info/git-delta.* /var/lib/dpk/info/
COPY --from=dive /usr/bin/dive /usr/bin/dive
COPY --from=dive /var/lib/dpkg/info/dive.* /var/lib/dpkg/info/
COPY --from=go /go/ /usr/local/
COPY --from=neovim /neovim/ /usr/
COPY --from=stylua /usr/bin/stylua /usr/bin/stylua

# This takes a while so we're leaving this at the end
COPY --from=node --chown=$USER:$GROUP $HOME/.local/share/fnm/ $HOME/.local/share/fnm/

RUN rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get autoremove -y;

FROM cleanup AS final
USER $USER
WORKDIR /workspace

RUN touch $HOME/.gitconfig $HOME/.git-credentials \
    && mkdir -p $HOME/.local/share/nvim;
