{ lib, stdenv, fetchurl, dpkg, buildFHSEnv, writeShellScript, symlinkJoin
, gtk3, libnotify, nss, nspr, at-spi2-core, at-spi2-atk, atk, libdrm, mesa, libgbm, libGL
, vulkan-loader, alsa-lib, cairo, cups, dbus, expat, gdk-pixbuf, glib
, pango, openssl, systemd, libusb1, libxkbcommon, zlib, fontconfig
, libx11, libxcb, libxcomposite, libxdamage, libxext, libxfixes, libxrandr
, xdg-utils, git, wayland, pipewire, libva, libdecor, libpulseaudio
}:

let
  version = "26.1013.40934";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    sha256 = "1mx1ydfvw3ia47xihx7z4s0apdc46xl81mlszgibjhb6k9zrx99w";
  };

  unpacked = stdenv.mkDerivation {
    pname = "chatgpt-data";
    inherit version src;
    sourceRoot = ".";
    nativeBuildInputs = [ dpkg ];
    installPhase = ''
      runHook preInstall
      dpkg-deb -x $src $out
      runHook postInstall
    '';
  };

  launch = writeShellScript "chatgpt-launch" ''
    export NIXOS_OZONE_WL=1
    export XDG_SESSION_TYPE=wayland
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    export SDL_VIDEODRIVER=wayland
    export GDK_BACKEND=wayland,x11
    export CLUTTER_BACKEND=wayland
    export XCURSOR_THEME=''${XCURSOR_THEME:-Adwaita}
    export XCURSOR_SIZE=''${XCURSOR_SIZE:-24}
    export WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-wayland-0}
    export XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    export ELECTRON_OZONE_PLATFORM_HINT=wayland
    export OZONE_PLATFORM_HINT=wayland
    exec ${unpacked}/usr/lib/chatgpt/ChatGPT \
      --ozone-platform=wayland \
      --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer \
      --ozone-platform-hint=wayland \
      --enable-wayland-ime \
      --disable-gpu-vsync \
      "$@"
  '';

  fhs = buildFHSEnv {
    name = "chatgpt-fhs";
    executableName = "chatgpt";
    runScript = launch;
    targetPkgs = p: with p; [
      gtk3 libnotify nss nspr at-spi2-core at-spi2-atk atk libdrm mesa libgbm libGL
      vulkan-loader alsa-lib cairo cups dbus expat gdk-pixbuf glib
      pango openssl systemd libusb1 libxkbcommon zlib stdenv.cc.cc fontconfig
      libx11 libxcb libxcomposite libxdamage
      libxext libxfixes libxrandr
      xdg-utils git wayland pipewire libva libdecor libpulseaudio
    ];
  };
in
symlinkJoin {
  name = "chatgpt-${version}";
  paths = [ fhs ];
  postBuild = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/512x512/apps
    cp ${unpacked}/usr/lib/chatgpt/resources/icon-chatgpt.png \
      $out/share/icons/hicolor/512x512/apps/chatgpt.png
    cp ${unpacked}/usr/share/applications/chatgpt.desktop \
      $out/share/applications/chatgpt.desktop
  '';
  meta = with lib; {
    description = "ChatGPT / Codex desktop app by OpenAI (official Linux build, wrapped in FHS; native Wayland via --ozone-platform=wayland)";
    homepage = "https://developers.openai.com/codex/app";
    downloadPage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
