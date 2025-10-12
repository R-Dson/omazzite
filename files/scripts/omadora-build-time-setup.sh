#!/bin/bash

# This script handles the build-time setup of the default user configuration
# by operating on the /etc/skel directory. It takes the path to the cloned
# omadora repository as its first argument.

set -oue pipefail

OMADORA_REPO_PATH="${1:-/etc/skel/.local/share/omadora}"

if [ -z "$1" ]; then
    echo "No omadora repository path provided. Defaulting to $OMADORA_REPO_PATH."
fi

if [ ! -d "$OMADORA_REPO_PATH" ]; then
    echo "Error: Omadora repository not found at $OMADORA_REPO_PATH"
    echo "Please ensure the omadora repository is cloned to this location."
    exit 1
fi

SKEL_DIR="/etc/skel"

echo "Starting build-time setup for $SKEL_DIR..."

echo "Creating user directories in $SKEL_DIR..."
mkdir -p "$SKEL_DIR/.local/share/fonts"
mkdir -p "$SKEL_DIR/.local/share/applications/icons"
mkdir -p "$SKEL_DIR/.config"
mkdir -p "$SKEL_DIR/.config/omadora/themes"
mkdir -p "$SKEL_DIR/.config/omadora/current"
mkdir -p "$SKEL_DIR/.config/omadora/branding"
mkdir -p "$SKEL_DIR/.config/btop/themes"
mkdir -p "$SKEL_DIR/.config/mako"

echo "Copying omadora configuration files to $SKEL_DIR..."
cp -r "$OMADORA_REPO_PATH/config/"* "$SKEL_DIR/.config/"
cp -r "$OMADORA_REPO_PATH/default/hypr/"* "$SKEL_DIR/.config/hypr/"
cp "$OMADORA_REPO_PATH/default/bashrc" "$SKEL_DIR/.bashrc"
cp "$OMADORA_REPO_PATH/default/xcompose" "$SKEL_DIR/.XCompose"
cp "$OMADORA_REPO_PATH/applications/icons/"*.png "$SKEL_DIR/.local/share/applications/icons/"
cp "$OMADORA_REPO_PATH/icon.txt" "$SKEL_DIR/.config/omadora/branding/about.txt"
cp "$OMADORA_REPO_PATH/logo.txt" "$SKEL_DIR/.config/omadora/branding/screensaver.txt"

echo "Cloning LazyVim starter into $SKEL_DIR/.config/nvim..."
rm -rf "$SKEL_DIR/.config/nvim"
git clone https://github.com/LazyVim/starter "$SKEL_DIR/.config/nvim"
rm -rf "$SKEL_DIR/.config/nvim/.git"

# echo "Copying custom LazyVim configurations..."
# cp -rf "$OMADORA_REPO_PATH/config/nvim/"* "$SKEL_DIR/.config/nvim/"

echo "Installing user-specific packages..."
pipx install terminaltexteffects

echo "Copying systemd user services to system-wide directory..."
mkdir -p /usr/lib/systemd/user
cp "$OMADORA_REPO_PATH/config/systemd/user/omadora-battery-monitor.service" /usr/lib/systemd/user/
cp "$OMADORA_REPO_PATH/config/systemd/user/omadora-battery-monitor.timer" /usr/lib/systemd/user/

echo "Setting permissions for omadora binaries..."
chmod +x "$OMADORA_REPO_PATH/bin/"*

echo "Creating dummy/modified scripts in omadora repository..."
echo -e '#!/bin/bash\nexit 0' > "$OMADORA_REPO_PATH/bin/omadora-migrate"
cat << 'EOF' > "$OMADORA_REPO_PATH/bin/omadora-pkg-install"
#!/bin/bash

fzf_args=(
  --multi
  # Use 'flatpak info' for the preview
  --preview 'flatpak remote-info {1} {2}'
  --preview-label='alt-p: toggle description, alt-j/k: scroll, tab: multi-select, F11: maximize'
  --preview-label-pos='bottom'
  --preview-window 'down:65%:wrap'
  --bind 'alt-p:toggle-preview'
  --bind 'alt-d:preview-half-page-down,alt-u:preview-half-page-up'
  --bind 'alt-k:preview-up,alt-j:preview-down'
  --color 'pointer:green,marker:green'
)
# Get a list of available Flatpak application IDs from all remotes
pkg_ids=$(flatpak remote-ls --app --columns=origin,application 2>/dev/null | fzf "${fzf_args[@]}" | awk '{print $2}')

if [[ -n "$pkg_ids" ]]; then
  # Convert newline-separated list into an array
  readarray -t pkgs <<< "$pkg_ids"
  
  flatpak install "${pkgs[@]}"
  omadora-show-done
fi
EOF
sed -i '1,$d' "$OMADORA_REPO_PATH/bin/omadora-update-system-pkgs" && echo -e '#!/bin/bash\nexit 0' > "$OMADORA_REPO_PATH/bin/omadora-update-system-pkgs"
sed -i '1,$d' "$OMADORA_REPO_PATH/bin/omadora-pkg-remove" && echo -e '#!/bin/bash\nexit 0' > "$OMADORA_REPO_PATH/bin/omadora-pkg-remove"
chmod +x "$OMADORA_REPO_PATH/bin/omadora-pkg-install"

echo "Creating power profile scripts in omadora repository..."
echo -e "#!/bin/bash\nprofile=\"\$1\"\nif sudo tuned-adm profile \"\$profile\"; then\n    notify-send -a \"PowerProfiles\" \"Power profile set to '\$profile'\"\nelse\n    notify-send -a \"PowerProfiles\" \"Failed to set power profile to '\$profile'\"\n    exit 1\nfi" > "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-set" && chmod +x "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-set"
echo -e '#!/bin/bash\ntuned-adm list | awk '\''/^ *- / {print}'\'' | sed -E '\''s/^ *- ([^[:space:]]+).*$/\1/'\'' | xargs -n1' > "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-list" && chmod +x "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-list"

echo "Applying sed modifications to omadora scripts and configs..."
sed -i 's/$(powerprofilesctl get)/$(tuned-adm active | awk '\''{print $NF}'\'')/g' "$OMADORA_REPO_PATH/bin/omadora-menu"
sed -i 's/ --quiet//g' "$SKEL_DIR/.config/uwsm/env"
sed -i '/exec-once = uwsm app -- waybar/d' "$SKEL_DIR/.config/hypr/autostart.conf"
echo "Appending configurations to Hyprland config files in $SKEL_DIR..."
echo 'bind = SUPER, F4, exec, pavucontrol' >> "$SKEL_DIR/.config/hypr/bindings/media.conf"
echo 'exec-once = sleep 2 && pkill -x "waybar" && setsid uwsm app -- "waybar" >/dev/null 2>&1 &' >> "$SKEL_DIR/.config/hypr/autostart.conf"
echo 'exec-once = systemctl --user enable --now omadora-first-login.service' >> "$SKEL_DIR/.config/hypr/autostart.conf"


echo "Updating Waybar config in omadora repository..."
# Create temporary file for jq output to avoid issues with in-place editing
jq '(.["modules-center"][] | select(."custom/update"))["custom/update"] = { "exec": "/usr/bin/omadora-waybar-update", "on-click": "/usr/bin/omadora-waybar-update --launch-update", "return-type": "json", "interval": 3600 }' "$OMADORA_REPO_PATH/config/waybar/config.jsonc" > /tmp/waybar.jsonc && mv /tmp/waybar.jsonc "$OMADORA_REPO_PATH/config/waybar/config.jsonc"

SDDM_THEME_DEST_PATH="/usr/share/sddm/themes/silent"

if [ ! -d "$SDDM_THEME_DEST_PATH" ]; then
    echo "Error: SDDM theme not found at $SDDM_THEME_DEST_PATH."
    echo "Please ensure the theme is cloned to that location during the build process."
    exit 1
fi

if [ -d "$SDDM_THEME_DEST_PATH/fonts" ]; then
    echo "Copying theme fonts to /usr/share/fonts/sddm-silent-theme/..."
    mkdir -p /usr/share/fonts/sddm-silent-theme
    cp -r "$SDDM_THEME_DEST_PATH/fonts/"* /usr/share/fonts/sddm-silent-theme/
    echo "Rebuilding font cache..."
    fc-cache -f -v
fi

echo "Creating SDDM theme configuration in /etc/sddm.conf.d/..."
mkdir -p /etc/sddm.conf.d
cat << EOF > /etc/sddm.conf.d/silent-theme.conf
# Configuration for Omadora's default SDDM theme
# This file is automatically generated by the build script.

[Theme]
Current=silent

[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard
EOF


echo "Copying Omadora themes..."
# Copy all themes from the cloned omadora repository to the user's config directory.
cp -r "$OMADORA_REPO_PATH/themes/"* "$SKEL_DIR/.config/omadora/themes/"
ln -snf "$OMADORA_REPO_PATH/themes/rose-pine-darker" "$SKEL_DIR/.config/omadora/current/theme"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/backgrounds/01_background.png" "$SKEL_DIR/.config/omadora/current/background"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/neovim.lua" "$SKEL_DIR/.config/nvim/lua/plugins/theme.lua"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/btop.theme" "$SKEL_DIR/.config/btop/themes/current.theme"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/mako.ini" "$SKEL_DIR/.config/mako/config"

echo "Build-time setup complete."
