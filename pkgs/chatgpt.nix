{ lib
, stdenv
, fetchurl
, dpkg
, buildFHSEnv
, symlinkJoin
}:

# ChatGPT / Codex desktop app by OpenAI.
#
# OpenAI ships Linux as an Ubuntu .deb only (no Nix package, no source). This
# derivation unpacks that .deb and wraps the bundled Electron/Chromium binary in
# a buildFHSEnv sandbox so it finds its expected /usr/lib layout at runtime.

let
  version = "26.1007.21434";

  # NOTE: this is a /latest/ URL. When OpenAI publishes a new build the hash
  # below will stop matching and the build will fail loudly (never silently
  # fetch a different version). To bump, see README "Updating the version".
  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    sha256 = "sha256-J2tTQcPXSyYdOtUhBvf6ft3gaEHkdn/ipAy1QJmx8+0=";
  };

  # Unpack the official Ubuntu .deb (Chromium/Electron app bundle).
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

  fhs = buildFHSEnv {
    name = "chatgpt-fhs";
    # Name of the wrapper placed on PATH ($out/bin/<executableName>).
    # The .desktop file launches `chatgpt`, so this must match.
    executableName = "chatgpt";
    runScript = "${unpacked}/usr/lib/chatgpt/ChatGPT";
    # Force native Wayland (Electron Ozone) inside the sandbox.
    extraBwrapArgs = [ "--setenv" "ELECTRON_OZONE_PLATFORM_HINT" "wayland" ];
    # Runtime dependencies the bundled Chromium/Electron expects to dlopen.
    targetPkgs = p: with p; [
      gtk3 libnotify nss nspr at-spi2-core at-spi2-atk atk libdrm mesa libgbm libGL
      vulkan-loader alsa-lib cairo cups dbus expat gdk-pixbuf glib
      pango openssl systemd libusb1 libxkbcommon zlib stdenv.cc.cc fontconfig
      libx11 libxcb libxcomposite libxdamage
      libxext libxfixes libxrandr
      xdg-utils git
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
    description = "ChatGPT / Codex desktop app by OpenAI (official Linux build, wrapped in an FHS env)";
    homepage = "https://developers.openai.com/codex/app";
    downloadPage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
