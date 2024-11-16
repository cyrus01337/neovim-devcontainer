#!/usr/bin/env bash
eval "$(curl https://pyenv.run)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

pyenv install 3.11
pyenv virtualenv 3.11 home
pyenv global home

python -m pip install -U black isort pip
