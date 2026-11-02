# Login shells: macOS /etc/zprofile (path_helper) runs after .zshenv and puts system folders first.
source "${${(%):-%x}:A:h}/path.zsh"
