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
mkdir -p "$SKEL_DIR/.config/nvim"
mkdir -p "$SKEL_DIR/.config/nvim/lua/plugins"

echo "Cloning LazyVim starter into $SKEL_DIR/.config/nvim..."
git clone https://github.com/LazyVim/starter "$SKEL_DIR/.config/nvim"
rm -rf "$SKEL_DIR/.config/nvim/.git"

echo "Copying omadora configuration files to $SKEL_DIR..."
cp -r "$OMADORA_REPO_PATH/config/"* "$SKEL_DIR/.config/"
cp -r "$OMADORA_REPO_PATH/default/hypr/"* "$SKEL_DIR/.config/hypr/"
cp "$OMADORA_REPO_PATH/default/bashrc" "$SKEL_DIR/.bashrc"
cp "$OMADORA_REPO_PATH/default/xcompose" "$SKEL_DIR/.XCompose"
cp "$OMADORA_REPO_PATH/applications/icons/"*.png "$SKEL_DIR/.local/share/applications/icons/"
cp "$OMADORA_REPO_PATH/icon.txt" "$SKEL_DIR/.config/omadora/branding/about.txt"
cp "$OMADORA_REPO_PATH/logo.txt" "$SKEL_DIR/.config/omadora/branding/screensaver.txt"
cp -R "$OMADORA_REPO_PATH/config/nvim/"* "$SKEL_DIR/.config/nvim/"

echo "Copying systemd user services to system-wide directory..."
mkdir -p /usr/lib/systemd/user
cp "$OMADORA_REPO_PATH/config/systemd/user/omadora-battery-monitor.service" /usr/lib/systemd/user/
cp "$OMADORA_REPO_PATH/config/systemd/user/omadora-battery-monitor.timer" /usr/lib/systemd/user/

echo "Setting permissions for omadora binaries..."
chmod +x "$OMADORA_REPO_PATH/bin/"*

echo "Creating dummy/modified scripts in omadora repository..."
echo -e '#!/bin/bash\nexit 0' > "$OMADORA_REPO_PATH/bin/omadora-migrate"
sed -i '1,$d' "$OMADORA_REPO_PATH/bin/omadora-pkg-install" && echo -e '#!/bin/bash\nexit 0' > "$OMADORA_REPO_PATH/bin/omadora-pkg-install"
sed -i '1,$d' "$OMADORA_REPO_PATH/bin/omadora-update-system-pkgs" && echo -e '#!/bin/bash\nexit 0' > "$OMADORA_REPO_PATH/bin/omadora-update-system-pkgs"
sed -i '1,$d' "$OMADORA_REPO_PATH/bin/omadora-pkg-remove" && echo -e '#!/bin/bash\nexit 0' > "$OMADORA_REPO_PATH/bin/omadora-pkg-remove"
chmod +x "$OMADORA_REPO_PATH/bin/omadora-pkg-install"

echo "Creating power profile scripts in omadora repository..."
echo -e "#!/bin/bash\nprofile=\"\$1\"\nif sudo tuned-adm profile \"\$profile\"; then\n    notify-send -a \"PowerProfiles\" \"Power profile set to '\$profile'\"\nelse\n    notify-send -a \"PowerProfiles\" \"Failed to set power profile to '\$profile'\"\n    exit 1\nfi" > "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-set" && chmod +x "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-set"
echo -e '#!/bin/bash\ntuned-adm list | awk '\''/^ *- / {print}'\'' | sed -E '\''s/^ *- ([^[:space:]]+).*$/\1/'\'' | xargs -n1' > "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-list" && chmod +x "$OMADORA_REPO_PATH/bin/omadora-powerprofiles-list"

echo "Applying sed modifications to omadora scripts and configs..."
sed -i 's/$(powerprofilesctl get)/$(tuned-adm active | awk '\''{print $NF}'\'')/g' "$OMADORA_REPO_PATH/bin/omadora-menu"
# sed -i 's/alacritty --class=Wiremix -e wiremix "\$@"/alacritty --class=Pavucontrol -e pavucontrol "\$@"/g' "$OMADORA_REPO_PATH/bin/omadora-launch-audio"
sed -i 's/ --quiet//g' "$SKEL_DIR/.config/uwsm/env"

echo "Overwriting omadora-launch-audio with pavucontrol setup..."
cat <<'EOF' > "$OMADORA_REPO_PATH/bin/omadora-launch-audio"
#!/bin/bash

exec setsid uwsm app -- pavucontrol
EOF

echo "Appending configurations to Hyprland config files in $SKEL_DIR..."
echo 'bind = SUPER, F4, exec, pavucontrol' >> "$SKEL_DIR/.config/hypr/bindings/media.conf"
echo 'exec-once = sleep 2 && pkill -x "waybar" && setsid uwsm app -- "waybar" >/dev/null 2>&1 &' >> "$SKEL_DIR/.config/hypr/autostart.conf"

echo "Updating Waybar config in omadora repository..."
# Create temporary file for jq output to avoid issues with in-place editing
jq '(.["modules-center"][] | select(."custom/update"))["custom/update"] = { "exec": "/usr/bin/omadora-waybar-update", "on-click": "/usr/bin/omadora-waybar-update --launch-update", "return-type": "json", "interval": 3600 }' "$OMADORA_REPO_PATH/config/waybar/config.jsonc" > /tmp/waybar.jsonc && mv /tmp/waybar.jsonc "$OMADORA_REPO_PATH/config/waybar/config.jsonc"

echo "Creating symlinks for themes in $SKEL_DIR..."
# Note: The original script iterates /usr/share/themes/*, which is a runtime action.
# For build-time, we'll assume the themes are already available in the omadora repo
# or directly linked. For now, we'll just link the specific theme files.
# If /usr/share/themes is available at build time, the loop below can be uncommented.
# for theme in /usr/share/themes/*; do if [ -d "$theme" ]; then ln -nfs "$theme" "$SKEL_DIR/.config/omadora/themes/"; fi; done
ln -snf "$OMADORA_REPO_PATH/themes/rose-pine-darker" "$SKEL_DIR/.config/omadora/current/theme"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/backgrounds/01_background.png" "$SKEL_DIR/.config/omadora/current/background"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/neovim.lua" "$SKEL_DIR/.config/nvim/lua/plugins/theme.lua"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/btop.theme" "$SKEL_DIR/.config/btop/themes/current.theme"
ln -snf "$SKEL_DIR/.config/omadora/current/theme/mako.ini" "$SKEL_DIR/.config/mako/config"

echo "Build-time setup complete."