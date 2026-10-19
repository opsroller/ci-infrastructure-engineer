# Update the pinned Fedora CoreOS release

1. Regenerate the pin from the stream metadata:

   ```
   scripts/update-fcos-pin stable x86_64 > nix/fcos-pin.json
   ```

   It needs `curl` and `jq`; both are on `PATH` when direnv loads the flake (`.envrc` is `use flake`).

2. Run the boot test to confirm the new release boots:

   ```
   scripts/test-pxe-boot
   ```

3. Commit the change as `chore(deps): pin Fedora CoreOS <release>`.
