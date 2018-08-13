#!/usr/bin/env bash

###
# Power through the process of setting up a Mac for general use.
# @author Paul Stevens
###

# Colors
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_RED=$ESC_SEQ"31;01m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"
COL_BLUE=$ESC_SEQ"34;01m"
COL_MAGENTA=$ESC_SEQ"35;01m"
COL_CYAN=$ESC_SEQ"36;01m"

function ok() {
    echo -e "$COL_GREEN[ok]$COL_RESET "$1
}

function runner() {
    echo -e "\n$COL_GREEN[<_>]$COL_RESET - "$1
}

function doing() {
    echo -en "$COL_YELLOW ⇒ $COL_RESET"$1": "
}

function action() {
    echo -e "\n$COL_YELLOW[action]:$COL_RESET\n ⇒ $1..."
}

function warn() {
    echo -e "$COL_YELLOW[warning]$COL_RESET "$1
}

function error() {
    echo -e "$COL_RED[error]$COL_RESET "$1
}

runner "Hello! I'm going to install tooling and adjust system settings. Sit back and relax."
runner "First off: give me your sudo password so that I don't need to nag:"
sudo -v
# Fixed from https://github.com/atomantic/dotfiles/blob/master/install.sh
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###
# Install Homebrew
###

doing "checking for existing homebrew installations"
brew_loc=$(which brew) 2>&1 > /dev/null
if [[ $? != 0 ]]; then
  doing "running homebrew installation"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  if [[ $? != 0 ]]; then
    error "sorry. can't install homebrew. $0 abort!"
    exit 2
  else
    ok "installed homebrew. soldiering on..."
  fi
fi;

###
# Update brew and install stuff from the Brewfile
###
if which brew > /dev/null; then
  ok
  doing "updating brew packages..."
  brew update
  if [[ $? != 0 ]]; then
    error "oops. failed to update packages. $0 abort!"
  else
    ok "update successful"
  fi
  doing "installing stuffs from Brewfile. this is going to take a minute. tea?"
  brew bundle
  if [[ $? != 0 ]]; then
    error "oops. we appear to have some issues. $0 abort!"
    exit 2
  else
    ok "installed apps, taps and casks"
  fi
fi;

###
# Set shell to zsh version from brew
###
CURRSHELL=$(dscl . -read /Users/$USER UserShell | awk '{print $2}')
doing "setting shell to brew zsh..."
if [[ "$CURRSHELL" != "/usr/local/bin/zsh" ]]; then
  runner "setting your shell to the zsh from brew..."
  sudo dscl . -change /Users/$USER UserShell $SHELL /usr/local/bin/zsh > /dev/null 2>&1
  ok
fi

###
# Install Oh-My-ZSH
###
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  doing "installing ohmyzsh..."
  sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
  if [[ $? != 0 ]]; then
    error "oh dear. we had a problem. $0 abort!"
    exit 2
  else
    ok "installed ohmyzsh"
fi;

###
# Push dotfiles
###
doing "pushing dotfiles to $HOME"
pushd home > /dev/null 2>&1
for file in .*; do
  if [[ $file == "." || $file == ".." ]]; then
    continue
  fi
  doing "~/$file"
  if [[ -e ~/$file ]]; then
    mkdir -p ~/.dotfiles/backup
    mv ~/$file ~/.dotfiles/backup/$file
    echo "backed up $file to ~/.dotfiles/backup/$file"
  fi
  unlink ~/$file > /dev/null 2>&1
  ln -s ~/.bootstrap/home/$file ~/$file
  echo -en '\tlinked';ok
done
popd > /dev/null 2>&1

###
# Force quit system preferences
###
running "shutting any open system preference panes..."
osascript -e 'tell application "System Preferences" to quit'
ok

###
# Secure this MacBook
###
# Based on:
# https://github.com/drduh/macOS-Security-and-Privacy-Guide
# https://benchmarks.cisecurity.org/tools2/osx/CIS_Apple_OSX_10.12_Benchmark_v1.0.0.pdf

runner "securing this macbook..."
# Enable firewall
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 2
# Enable filewall stealth mode
sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1
# Prevent signed software from automatically receiving incoming connections
sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -bool false
# Enable firewall logging
sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1
# Rotate logs after 30 days
sudo perl -p -i -e 's/rotate=seq compress file_max=5M all_max=50M/rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf"
sudo perl -p -i -e 's/appfirewall.log file_max=5M all_max=50M/appfirewall.log rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf"
# Reload the firewall
launchctl unload /System/Library/LaunchAgents/com.apple.alf.useragent.plist
sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist
sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist
launchctl load /System/Library/LaunchAgents/com.apple.alf.useragent.plist
# Disable IR features
sudo defaults write /Library/Preferences/com.apple.driver.AppleIRController DeviceEnabled -bool false
# Disable Bluetooth
sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
sudo launchctl unload /System/Library/LaunchDaemons/com.apple.blued.plist
sudo launchctl load /System/Library/LaunchDaemons/com.apple.blued.plist
# Disable CAN
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false
# Disable remote Apple events
sudo systemsetup -setremoteappleevents off
# Disable remote login
sudo systemsetup -setremotelogin off
# Disable wake-on modem and wake-on LAN
sudo systemsetup -setwakeonmodem off
sudo systemsetup -setwakeonnetworkaccess off
# Disable file-sharing via SMB and AFP
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist
# No passwords hint
sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0
# Disable that damn guest account
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
# Lock the keychain after there's been no activity for 3 hours
security set-keychain-settings -t 10800 -l ~/Library/Keychains/login.keychain
# Destroy FileVault key when going into standby mode
sudo pmset destroyfvkeyonstandby 1
# Disable Bonjour multicast advertising
sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true
# Disable crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"
# Disable diagnostic reports
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist
# Log all auth attempts for 30 days
sudo perl -p -i -e 's/rotate=seq file_max=5M all_max=20M/rotate=utc file_max=5M ttl=30/g' "/etc/asl/com.apple.authd"
# Log installation events for a full year
sudo perl -p -i -e 's/format=bsd/format=bsd mode=0640 rotate=utc compress file_max=5M ttl=365/g' "/etc/asl/com.apple.install"
# Log kernel events for 30 days
sudo perl -p -i -e 's|flags:lo,aa|flags:lo,aa,ad,fd,fm,-all,^-fa,^-fc,^-cl|g' /private/etc/security/audit_control
sudo perl -p -i -e 's|filesz:2M|filesz:10M|g' /private/etc/security/audit_control
sudo perl -p -i -e 's|expire-after:10M|expire-after: 30d |g' /private/etc/security/audit_control
# Disable the confirm open applicatio dialogue
defaults write com.apple.LaunchServices LSQuarantine -bool false
ok "finished securing this system."

###
# SSD tweaks
###
runner "Tweaking SSD settings to improve performance"
sudo tmutil disablelocal;ok
sudo pmset -a hibernatemode 0;ok
sudo rm -rf /Private/var/vm/sleepimage;ok
sudo touch /Private/var/vm/sleepimage;ok
sudo chflags uchg /Private/var/vm/sleepimage;ok
sudo pmset -a sms 0;ok

###
# Window dressing
###
runner "changing hostname"
sudo scutil --set ComputerName "arktos"
sudo scutil --set HostName "arktos"
sudo scutil --set LocalHostName "arktos"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "arktos"

runner "enable the 'locate' command"
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist > /dev/null 2>&1;ok

runner "delay standby timer for 24 hours"
sudo pmset -a standbydelay 86400;ok
