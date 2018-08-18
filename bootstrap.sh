#!/usr/bin/env bash

###
# Power through the process of setting up a Mac for general use.
# @author Paul Stevens
###

# Colors
ESC_SEQ="\x1b["
COL_RESET=$ESC_SEQ"39;49;00m"
COL_GREEN=$ESC_SEQ"32;01m"
COL_YELLOW=$ESC_SEQ"33;01m"

function ok() {
    echo -e "$COL_GREEN[ok]$COL_RESET "$1
}

function runner() {
    echo -e "\n$COL_GREEN[<_>]$COL_RESET - "$1
}

function doing() {
    echo -en "$COL_YELLOW ⇒ $COL_RESET"$1": "
}

runner "Hello! I'm going to install tooling and adjust system settings. Sit back and relax."
runner "First off: give me your sudo password so that I don't need to nag:"
sudo -v
# Fixed from https://github.com/atomantic/dotfiles/blob/master/install.sh
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###
runner "Installing XCode Command Line Tools."
###
doing "installing command line tools..."
xcode-select --install > /dev/null 2>&1;ok

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
pushd ~/.bootstrap/home > /dev/null 2>&1
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
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 2
sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1
sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -bool false
sudo defaults write /Library/Preferences/com.apple.alf loggingenabled -int 1;ok

doing "changing log handling..."
# Rotate logs after 30 days
sudo perl -p -i -e 's/rotate=seq compress file_max=5M all_max=50M/rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf"
sudo perl -p -i -e 's/appfirewall.log file_max=5M all_max=50M/appfirewall.log rotate=utc compress file_max=5M ttl=30/g' "/etc/asl.conf";ok

doing "disabling Captive Network Assistant..."
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false;ok

doing "disabling wake on lan..."
sudo systemsetup -setwakeonnetworkaccess off > /dev/null 2>&1;ok

doing "disabling password hints..."
sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0;ok

doing "disabling guest account..."
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false;ok

doing "changing keychain lock timeouts and FileVault keystore timeouts..."
security set-keychain-settings -t 10800 -l ~/Library/Keychains/login.keychain
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

doing "changing hostname..."
sudo scutil --set ComputerName "arktos"
sudo scutil --set HostName "arktos"
sudo scutil --set LocalHostName "arktos"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "arktos";ok

doing "enable the 'locate' command..."
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.locate.plist > /dev/null 2>&1;ok

doing "delay standby timer for 24 hours..."
sudo pmset -a standbydelay 86400;ok

doing "expand save panel by default..."
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true;ok

doing "check for software updates daily, not just once a week..."
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1;ok

doing "save to disk by default..."
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false;ok

doing "disable the automatic termination of inactive apps..."
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true;ok

doing "never go into sleep mode..."
sudo systemsetup -setcomputersleep Off > /dev/null;ok

doing "disabling press and hold for keys..."
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false;ok

doing "set fast key repeat speed..."
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 10;ok

doing "requiring password immediately after screensaver or sleep..."
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0;ok

doing "defaulting to show finder status bar..."
defaults write com.apple.finder ShowStatusBar -bool true;ok

doing "defaulting to show finder path bar..."
defaults write com.apple.finder ShowPathbar -bool true;ok

doing "display full POSIX path in finder window title..."
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true;ok

doing "disable warnings when changing file extensions..."
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false;ok

doing "avoid creating .DS_Store files on network volumes..."
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true;ok

doing "default to list view in finder..."
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv";ok

doing "disable warnings before emptying trash..."
defaults write com.apple.finder WarnOnEmptyTrash -bool false;ok

doing "empty trash securely..."
defaults write com.apple.finder EmptyTrashSecurely -bool true;ok

doing "set dock icons to 36 pixels..."
defaults write com.apple.dock tilesize -int 36;ok

doing "minimize windows to their dock icon..."
defaults write com.apple.dock minimize-to-application -bool true;ok

doing "show indicator lights for any open apps in the dock..."
defaults write com.apple.dock show-process-indicators -bool true;ok

doing "don't group windows by application in Mission Control..."
defaults write com.apple.dock expose-group-by-app -bool false;ok

doing "don't automatically rearrange Spaces by most recently used..."
defaults write com.apple.dock mru-spaces -bool false;ok

doing "set Safari home page to about:blank..."
defaults write com.apple.Safari HomePage -string "about:blank";ok

doing "stop Safari from opening safe files by default after downloading them..."
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false;ok

doing "allow backspace key to act as a back button..."
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true;ok

doing "hide bookmark bar by default..."
defaults write com.apple.Safari ShowFavoritesBar -bool false;ok

doing "disable thumbnail cache for History and Top Sites..."
defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2;ok

doing "enable Safari debug menu..."
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true;ok

doing "enable developer menu and web inspector..."
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true;ok

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
mkdir ~/.ssh > /dev/null 2>&1
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
defaults write com.googlecode.iterm2 Hotkey -bool true
defaults write com.googlecode.iterm2 HotkeyChar -int 96
defaults write com.googlecode.iterm2 HotkeyCode -int 50
defaults write com.googlecode.iterm2 HotkeyModifiers -int 262401;ok

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
runner "Setting up Go workspace stuff"
###

doing "creating a go root..."
# See https://golang.org/doc/code.html#GOPATH
mkdir -p ~/Code/golang;ok

###
runner "Setting up Ruby"
###
doing "installing ruby 2.5.1..."
rbenv install -f 2.5.1 > /dev/null 2>&1;ok
doing "setting new ruby version to global..."
rbenv global 2.5.1 > /dev/null 2>&1;ok

###
runner "Installing App Store applications"
###
doing "installing 1Password..."
sudo mas install --force 1333542190 > /dev/null 2>&1;ok
doing "installing NordVPN IKE..."
sudo mas install --force 1116599239 > /dev/null 2>&1;ok
doing "installing Microsoft Remote Desktop..."
sudo mas install --force 1295203466 > /dev/null 2>&1;ok
doing "installing Core Tunnel - SSH Tunnel 2..."
sudo mas install --force 1354318707 > /dev/null 2>&1;ok
doing "installing WhatsApp Desktop..."
sudo mas install --force 1147396723 > /dev/null 2>&1;ok
doing "installing WriteRoom..."
sudo mas install --force 417967324 > /dev/null 2>&1;ok

###
runner "Downloading software to ~/Downloads"
###

doing "downloading SteelSeriesEngine..."
wget https://steelseries.com/engine/latest/darwin -O ~/Downloads/SteelSeriesEngine.pkg > /dev/null 2>&1;ok
doing "downloading Skype..."
wget https://go.skype.com/mac.download -O ~/Downloads/Skype.dmg > /dev/null 2>&1;ok

###
runner "We're done! Thank you for playing."
###
