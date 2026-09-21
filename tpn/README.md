# In-image third-party notices

`bash tpn/tpn-gen.sh > THIRD-PARTY-NOTICES.md` reads the completed image's package database and installed notices, offline. Run separately for each platform. Keep the helper files beside the script. Requirements are Bash 4+, POSIX awk, coreutils, sed, grep, and RPM on RPM images.

Debian declarations come from DEP-5 license synopses; exception clauses are retained. Empty synopses do not turn the following prose into identifiers. Held packages, architecture-independent packages, multiarch packages and symlinked documentation are included. Free-text matches are marked **detected**. They identify recognizable statements, with versions when available, but cannot prove the applicability of every mention in arbitrary prose. Unknown text remains verbatim. Copyright extraction retains whole statements, including wrapped names and yearless ownership statements.

RPM declarations remain exactly as recorded in the header. The script reads `%license` files and files with conventional notice names, then tries embedded POD license sections, installed siblings with the same source RPM, and recognizable standard texts already in the image. Every borrowed text identifies its source. A generic BSD or MIT text is a donor example: package-specific notices, license variants and exceptions cannot be reconstructed from the header. Missing information is reported explicitly; donor copyright holders are never presented as the missing package's holders.

The common-license appendix reproduces referenced files and reports broken references. Markdown fences adapt to literal backticks in license text.

`components.tsv` is the only package-specific manifest. It lists the Dockerfile, downloaded component, version, source, declared license, installed path and notice source. The pipe delimiter keeps values readable. The manifest covers standard and precompiled Ubuntu/RHEL images. Standard Ubuntu 26.04 supplies its driver through installed packages and bundled archives, so its standalone manifest is explicitly empty; Rocky uses the RHEL Dockerfiles. It includes:

- Driver `LICENSE` and verbatim `html/acknowledgements.html`, extracted from the shipped runfile in the disposable TPN stage. Precompiled images preserve these notices when the installer is first extracted.
- donkey 1.1.0's ISC notice, copied from [its versioned source](https://github.com/3XX0/donkey/blob/v1.1.0/donkey.c).
- extract-vmlinux's copyright/SPDX header and GPL-2.0 text. Its download and manifest use the same kernel commit. The bundled license comes from [the kernel license directory](https://github.com/torvalds/linux/blob/fe2ec83746e501645709761605c2464a44fd2929/LICENSES/preferred/GPL-2.0).

The generator downloads nothing. Driver extraction uses the runfile's existing extraction dependencies. Ubuntu images with a bundled repository use a separate build adapter that uses the image's `dpkg-deb` to unpack bundled repository archives; the generator reads those files in a separate section. Each archive has a separate directory to preserve versions and architectures. Only notices are copied into the final image, and existing `/licenses` content is retained.

Set `TPN_IMAGE` and `TPN_PLATFORM` for document metadata. Set `TPN_DOCKERFILE` to a manifest key and `TPN_BASE_URL` when the driver download URL differs. `TPN_ARCHIVES` optionally names the directory prepared by `prepare-archives.sh`. vGPU Go module notices are outside the tested scope.

Run `bash tpn/tests/parser.sh` for synthetic parser regressions. Image-level checks must compare installed names, versions, architectures, declarations and verbatim files against that same image; matching a broad license-family regex is not proof of complete license identification. The [Debian copyright format](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/) defines the distinction between a synopsis and its following license text.
