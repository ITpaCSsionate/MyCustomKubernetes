function set-title() {
  if [[ -z "" ]]; then
    ORIG=\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ 
  fi
  TITLE="\[\e]2;\a\]"
  PS1=
}
set-title 
