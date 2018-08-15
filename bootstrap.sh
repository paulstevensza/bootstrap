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

brew_loc=$(which brew) 2>&1 > /dev/null
if [[ $? != 0 ]]; then
  doing "running homebrew installation"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" > /dev/null 2>&1;ok
  if [[ $? != 0 ]]; then
    error "sorry. can't install homebrew. $0 abort!"
    exit 2
  fi
fi;

doing "Updating brew and installing software..."
brew bundle > /dev/null 2>&1;ok

###
runner "Setting shell to brew variant of ZSH"
###
CURRSHELL=$(dscl . -read /Users/$USER UserShell | awk '{print $2}')
if [[ "$CURRSHELL" != "/usr/local/bin/zsh" ]]; then
  doing "setting your shell to zsh installed from brew..."
  sudo dscl . -change /Users/$USER UserShell $SHELL /usr/local/bin/zsh > /dev/null 2>&1;ok
fi

###
runner "Installing ohmyzsh"
###
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  doing "installing ohmyzsh..."
  sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)" > /dev/null 2>&1;ok
fi;

###
runner "Pushing dotfiles"
###
doing "pushing dotfiles to $HOME";ok
pushd home > /dev/null 2>&1
for file in .*; do
  if [[ $file == "." || $file == ".." ]]; then
    continue
  fi
  doing "~/$file"
  cp ~/.bootstrap/home/$file ~/$file;ok
done;
popd > /dev/null 2>&1

###
runner "Force quitting System Preferences panes (if any are open)"
###
doing "shutting any open System Preferences panes..."
osascript -e 'tell application "System Preferences" to quit';ok

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
sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1;ok

doing "changing log handling..."
# Rotate logs after 30 days
sudo perl -p -i -e 's/rotate=seq compress file_max=5M all_max=50M/rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf"
sudo perl -p -i -e 's/appfirewall.log file_max=5M all_max=50M/appfirewall.log rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf";ok

# BUG: SIP again.
# doing "restarting firewall..."
# # Reload the firewall
# launchctl unload /System/Library/LaunchAgents/com.apple.alf.useragent.plist
# sudo launchctl unload /System/Library/LaunchDaemons/com.apple.alf.agent.plist
# sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist
# launchctl load /System/Library/LaunchAgents/com.apple.alf.useragent.plist;ok

# BUG: Incorrect paths to bluetooth plist
# doing "disabling IR and BlueTooth features..."
# # Disable IR features
# sudo defaults write /Library/Preferences/com.apple.driver.AppleIRController DeviceEnabled -bool false
# # Disable Bluetooth
# sudo defaults write /Library/Preferences/com.apple.Bluetooth ControllerPowerState -int 0
# sudo launchctl unload /System/Library/LaunchDaemons/com.apple.blued.plist
# sudo launchctl load /System/Library/LaunchDaemons/com.apple.blued.plist

doing "disabling Captive Network Assistant..."
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false;ok

# BUG: requires additional input
# doing "disabling remote access and remote features..."
# # Disable remote Apple events
# sudo systemsetup -setremoteappleevents off
# # Disable remote login
# sudo systemsetup -setremotelogin off

# BUG: wakeonmodem not supported
# Disable wake-on modem and wake-on LAN
#sudo systemsetup -setwakeonmodem off
doing "disabling wake on lan..."
sudo systemsetup -setwakeonnetworkaccess off > /dev/null 2>&1;ok

# BUG: Services not found
# doing "disabling file sharing..."
# # Disable file-sharing via SMB and AFP
# sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist
# sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist;ok

doing "disabling password hints..."
# No passwords hint
sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0;ok

doing "disabling guest account..."
# Disable that damn guest account
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false;ok

doing "changing keychain lock timeouts and FileVault keystore timeouts..."
# Lock the keychain after there's been no activity for 3 hours
security set-keychain-settings -t 10800 -l ~/Library/Keychains/login.keychain
# Destroy FileVault key when going into standby mode
sudo pmset destroyfvkeyonstandby 1;ok

doing "disabling Bonjour broadcast events..."
sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true;ok

# BUG: fails while SIP is enabled
# doing "disabling crash reporter and diagnostic reports..."
# # Disable crash reporter
# defaults write com.apple.CrashReporter DialogType -string "none"
# # Disable diagnostic reports
# sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist

doing "log all auth attempts for 30 days..."
# Log all auth attempts for 30 days
sudo perl -p -i -e 's/rotate=seq file_max=5M all_max=20M/rotate=utc file_max=5M ttl=30/g' "/etc/asl/com.apple.authd";ok
doing "log installation events for a full year"
sudo perl -p -i -e 's/format=bsd/format=bsd mode=0640 rotate=utc compress file_max=5M ttl=365/g' "/etc/asl/com.apple.install";ok
doing "log kernel events for 30 days"
sudo perl -p -i -e 's|flags:lo,aa|flags:lo,aa,ad,fd,fm,-all,^-fa,^-fc,^-cl|g' /private/etc/security/audit_control
sudo perl -p -i -e 's|filesz:2M|filesz:10M|g' /private/etc/security/audit_control
sudo perl -p -i -e 's|expire-after:10M|expire-after: 30d |g' /private/etc/security/audit_control;ok

doing "disabling confirm open application dialogue..."
defaults write com.apple.LaunchServices LSQuarantine -bool false;ok

###
runner "Tweaking SSD settings"
###

doing "disable hibernation..."
sudo pmset -a hibernatemode 0;ok
doing "disable sudden motion sensor..."
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
runner "Installing additional fonts"
###

doing "accessing and installing fonts..."
pushd ~/.bootstrap/fonts > /dev/null 2>&1
./install.sh > /dev/null 2>&1
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
defaults read -app iTerm > /dev/null 2>&1;ok

###
runner "Updating hosts to unfuck the Internet a bit..."
###

doing "backing up exiting hosts file..."
sudo cp /etc/hosts /etc/hosts.bak;ok
doing "implementing a new hosts file"
sudo wget https://someonewhocares.org/hosts/hosts -O /etc/hosts > /dev/null 2>&1;ok

###
runner "Configuring Atom"
###

doing "checking to see if atom is installed..."
atom_loc=$(which atom) > /dev/null 2>&1
if [[  $? != 0 ]]; then
  read -r -p "Please install Atom properly and press y to continue." response

  if [[ $response =~ (y|Y) ]]; then
    continue
  fi
fi;
ok

doing "checking to see if apm is installed..."
apm_loc=$(which apm) > /dev/null 2>&1
if [[ $? != 0 ]]; then
  read -r -p "Please install apm from the command pallete and press y to continue." response

  if [[ $response =~ (y|Y) ]]; then
    continue
  fi
fi;
ok

doing "apm disable language-python"
apm disable language-python > /dev/null 2>&1;ok

doing "apm install magicpython..."
apm install magicpython > /dev/null 2>&1;ok
doing "apm install atom-jinja2..."
apm install atom-jinja2 > /dev/null 2>&1;ok
doing "apm install autocomplete-python..."
apm install autocomplete-python > /dev/null 2>&1;ok
doing "apm install autocomplete-sql..."
apm install autocomplete-sql > /dev/null 2>&1;ok
doing "apm install git-plus..."
apm install git-plus > /dev/null 2>&1;ok
doing "apm install kite..."
apm install kite > /dev/null 2>&1;ok
doing "apm install language-docker..."
apm install language-docker > /dev/null 2>&1;ok
doing "apm install language-pgsql..."
apm install language-pgsql > /dev/null 2>&1;ok
doing "apm install language-protobuf..."
apm install language-protobuf > /dev/null 2>&1;ok
doing "apm install language-sql-mysql..."
apm install language-sql-mysql > /dev/null 2>&1;ok
doing "apm install markdown-preview-plus..."
apm install markdown-preview-plus > /dev/null 2>&1;ok

###
runner "Creating a generic Python virtualenv"
###

doing "creating virtualenv..."
pyenv virtualenv 3.6.6 ~/.virtualenv/py36 > /dev/null 2>&1;ok
doing "upgrading installers..."
~/.pyenv/shims/pip install --upgrade -r pip-upgrades.txt > /dev/null 2>&1;ok
doing "installing requirements..."
~/.pyenv/shims/pip install --upgrade -r requirements.txt > /dev/null 2>&1;ok

###
runner "We're done! Thank you for playing."
###
