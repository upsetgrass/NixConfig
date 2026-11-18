{ pkgs }:

let
  # Backport Pi 1.5.2 from nixpkgs b228aa104775 without changing the shared pin.
  base = pkgs.pi-coding-agent.overrideAttrs (final: previous: {
    version = "1.5.2";
    src = pkgs.fetchFromGitHub {
      owner = "earendil-works";
      repo = "pi";
      tag = "v${final.version}";
      hash = "sha256-0dKtABQqfvCLF0WOydu5rpycMqC+N8Pc9Ex4BWKElyw=";
    };
    npmDeps = pkgs.fetchNpmDeps {
      inherit (final) src;
      name = "pi-coding-agent-${final.version}-npm-deps";
      hash = "sha256-uHehffbEB2uU9U9uSpfWojzxvQyqeicbh/esCwk4neQ=";
    };
    modelData = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${final.version}.tgz";
      hash = "sha256-1XFe+oNMI7/fEKBCtJ307hacyZAAvxbXmY+rLVM7Rfg=";
    };
    postInstall = builtins.replaceStrings
      [ "@earendil-works/pi-mcp:packages/mcp" "-type l -lname '*/packages/*' -delete" ]
      [ "@earendil-works/pi-schema:packages/schema @earendil-works/pi-mcp:packages/mcp" "-type l \\( -lname '*/packages/*' -o -lname '*/apps/*' \\) -delete" ]
      previous.postInstall;
  });
  # Leave room for the search box, borders, scroll count, and standard footer.
  visibleRows = "Math.max(1,(process.stdout.rows||24)-14)";
  bundleAnchor = "onRenameSession;onError;maxVisible=10;";
in
pkgs.runCommand "${base.name}-adaptive-resume" { inherit (base) meta; } ''
  # Patch the packaged output to reuse nixpkgs' cached Pi build.
  cp -a --reflink=auto ${base} "$out"
  chmod -R u+w "$out"

  dist="$out/lib/node_modules/pi-monorepo/dist"
  mapfile -t chunks < <(grep -lF '${bundleAnchor}' "$dist"/bundle/chunks/*.js)
  if [ "''${#chunks[@]}" -ne 1 ]; then
    echo 'Pi session selector bundle changed; update usr/pi/resume-package.nix' >&2
    exit 1
  fi
  substituteInPlace "''${chunks[0]}" \
    --replace-fail '${bundleAnchor}' 'onRenameSession;onError;get maxVisible(){return ${visibleRows}}'
  substituteInPlace "$dist/modes/interactive/components/session-selector.js" \
    --replace-fail 'maxVisible = 10;' 'get maxVisible() { return ${visibleRows}; }'

  mapfile -t hotkeysChunks < <(grep -lF '**Navigation**' "$dist"/bundle/chunks/*.js)
  if [ "''${#hotkeysChunks[@]}" -ne 1 ]; then
    echo 'Pi /hotkeys bundle changed; update usr/pi/localize-hotkeys.mjs' >&2
    exit 1
  fi
  ${pkgs.nodejs_24}/bin/node ${./localize-hotkeys.mjs} \
    "$dist/modes/interactive/interactive-mode.js" "''${hotkeysChunks[0]}"

  substituteInPlace "$out/bin/pi" "$out/bin/.pi-wrapped" \
    --replace-fail '${base}/' "$out/"
''
