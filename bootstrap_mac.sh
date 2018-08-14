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
runner "Installing Homebrew"
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
runner "Updating brew and installing software"
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
runner "Setting shell to brew variant of ZSH"
###
CURRSHELL=$(dscl . -read /Users/$USER UserShell | awk '{print $2}')
doing "setting shell to brew zsh..."
if [[ "$CURRSHELL" != "/usr/local/bin/zsh" ]]; then
  runner "setting your shell to the zsh from brew..."
  sudo dscl . -change /Users/$USER UserShell $SHELL /usr/local/bin/zsh > /dev/null 2>&1
  ok
fi

###
runner "Installing OhMyZSH"
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
runner "Pushing dotfiles"
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
done;
popd > /dev/null 2>&1

###
runner "Installing packages from NPM"
###
if [[ ! which vtop ]]; then
  sudo npm install -g vtop
fi;

###
runner "Force quitting System Preferences panes (if any are open)"
###
doing "shutting any open system preference panes..."
osascript -e 'tell application "System Preferences" to quit'
ok

###
runner "Securing macOS"
###
# Based on:
# https://github.com/drduh/macOS-Security-and-Privacy-Guide
# https://benchmarks.cisecurity.org/tools2/osx/CIS_Apple_OSX_10.12_Benchmark_v1.0.0.pdf

doing "implementing firewall changes..."
# Enable firewall
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 2
# Enable filewall stealth mode
sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1
# Prevent signed software from automatically receiving incoming connections
sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -bool false
# Enable firewall logging
sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1

doing "changing log handling..."
# Rotate logs after 30 days
sudo perl -p -i -e 's/rotate=seq compress file_max=5M all_max=50M/rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf"
sudo perl -p -i -e 's/appfirewall.log file_max=5M all_max=50M/appfirewall.log rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf"

doing "restarting firewall..."
# Reload the firewall
launchctl unload /System/Library/LaunchAgents/com.apple.alf.useragent.plist
sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist
sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist
launchctl load /System/Library/LaunchAgents/com.apple.alf.useragent.plist

doing "disabling IR and BlueTooth features..."
# Disable IR features
sudo defaults write /Library/Preferences/com.apple.driver.AppleIRController DeviceEnabled -bool false
# Disable Bluetooth
sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
sudo launchctl unload /System/Library/LaunchDaemons/com.apple.blued.plist
sudo launchctl load /System/Library/LaunchDaemons/com.apple.blued.plist

doing "disabling Captive Network Assistant..."
# Disable CNA
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false

doing "disabling remote access and remote features..."
# Disable remote Apple events
sudo systemsetup -setremoteappleevents off
# Disable remote login
sudo systemsetup -setremotelogin off
# Disable wake-on modem and wake-on LAN
sudo systemsetup -setwakeonmodem off
sudo systemsetup -setwakeonnetworkaccess off

doing "disabling file sharing..."
# Disable file-sharing via SMB and AFP
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist

doing "disabling password hints..."
# No passwords hint
sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0

doing "disabling guest account..."
# Disable that damn guest account
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

doing "changing keychain lock timeouts and FileVault keystore timeouts..."
# Lock the keychain after there's been no activity for 3 hours
security set-keychain-settings -t 10800 -l ~/Library/Keychains/login.keychain
# Destroy FileVault key when going into standby mode
sudo pmset destroyfvkeyonstandby 1

doing "disabling Bonjour broadcast events..."
# Disable Bonjour multicast advertising
sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true

doing "disabling crash reporter and diagnostic reports..."
# Disable crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"
# Disable diagnostic reports
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist

doing "changing log rotation features..."
# Log all auth attempts for 30 days
sudo perl -p -i -e 's/rotate=seq file_max=5M all_max=20M/rotate=utc file_max=5M ttl=30/g' "/etc/asl/com.apple.authd"
# Log installation events for a full year
sudo perl -p -i -e 's/format=bsd/format=bsd mode=0640 rotate=utc compress file_max=5M ttl=365/g' "/etc/asl/com.apple.install"
# Log kernel events for 30 days
sudo perl -p -i -e 's|flags:lo,aa|flags:lo,aa,ad,fd,fm,-all,^-fa,^-fc,^-cl|g' /private/etc/security/audit_control
sudo perl -p -i -e 's|filesz:2M|filesz:10M|g' /private/etc/security/audit_control
sudo perl -p -i -e 's|expire-after:10M|expire-after: 30d |g' /private/etc/security/audit_control

doing "disabling confirm open application dialogue..."
# Disable the confirm open application dialogue
defaults write com.apple.LaunchServices LSQuarantine -bool false

ok "finished securing this system."

###
runner "Tweaking SSD settings"
###

doing "tweaking SSD settings to improve performance"
sudo tmutil disablelocal;ok
sudo pmset -a hibernatemode 0;ok
sudo rm -rf /Private/var/vm/sleepimage;ok
sudo touch /Private/var/vm/sleepimage;ok
sudo chflags uchg /Private/var/vm/sleepimage;ok
sudo pmset -a sms 0;ok

###
runner "Changing misc settings"
###

doing "changing hostname"
sudo scutil --set ComputerName "arktos"
sudo scutil --set HostName "arktos"
sudo scutil --set LocalHostName "arktos"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "arktos";ok

doing "enable the 'locate' command"
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist > /dev/null 2>&1;ok

doing "delay standby timer for 24 hours"
sudo pmset -a standbydelay 86400;ok

doing "Expand save panel by default"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true;ok

doing "Check for software updates daily, not just once a week"
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1;ok

###
runner "Time Machine configuration"
###

doing "don't use new drives as backup volumes..."
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true;ok

doing "disable local Time Machine backups..."
hash tmutil &> /dev/null && sudo tmutil disablelocal;ok

###
runner "Tweaking Activity Monitor settings"
###

doing "show the main window on launch..."
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true;ok

doing "visualize CPU usage in Dock icon..."
defaults write com.apple.ActivityMonitor IconType -int 5;ok

doing "show all processes..."
defaults write com.apple.ActivityMonitor ShowCategory -int 0;ok

doing "Sort results by CPU usage..."
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0;ok

###
runner "Managing SSH configs, keys and permissions"
###

doing "importing ssh stuff..."
pushd ~/Documents/Backups/SSH > /dev/null 2>&1
for file in *; do
  doing "$file"
  cp $file ~/.ssh/$file
done;
popd > /dev/null 2>&1
ok

doing "fixing ssh permissions..."
chmod 0700 ~/.ssh
pushd ~/.ssh > /dev/null 2>&1
for file in *; do
  chmod 0600 $file
done;
popd > /dev/null 2>&1
ok

###
runner "Configuring iTerm2"
###

doing "enabling focus follows mouse..."
defaults write com.apple.terminal FocusFollowsMouse -bool true;ok

doing "installing Solarized Light theme for iTerm..."
open "./configs/Solarized Light.itermcolors";ok

doing "installing Solarized Dark (patched) theme for iTerm..."
open "./configs/Solarized Dark Patch.itermcolors";ok

doing "don't display prompt when closing iTerm..."
defaults write com.googlecode.iterm2 PromptOnQuit -bool false;ok

doing "hide tab title bars..."
defaults write com.googlecode.iterm2 HideTab -bool true;ok

doing "set system wide hotkey to show/hide iterm with ^\`"
defaults write com.googlecode.iterm2 Hotkey -bool true;ok

doing "setting up fonts..."
defaults write com.googlecode.iterm2 "Normal Font" -string "Hack-Regular 12";
defaults write com.googlecode.iterm2 "Non Ascii Font" -string "RobotoMonoForPowerline-Regular 12";
ok

doing "reading iterm2 settings..."
defaults read -app iTerm > /dev/null 2>&1;

###
runner "Updating hosts to unfuck the Internet a bit..."
###

doing "backing up exiting hosts file and implementing a new one..."
action "cp /etc/hosts /etc/hosts.bak"
sudo cp /etc/hosts /etc/hosts.bak
ok
action "wget https://someonewhocares.org/hosts/hosts -O /etc/hosts"
sudo wget https://someonewhocares.org/hosts/hosts -O /etc/hosts
ok
