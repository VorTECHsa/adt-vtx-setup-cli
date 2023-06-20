# Vortexa Setup Utility 🚀

This is a tool that automates the setup of a typical engineer's MacOS machine at Vortexa.

See the **Why** section at the bottom of this document for more information.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/VorTECHsa/adt-vtx-setup-cli/main/setup.sh -o setup.sh && sh setup.sh adt
```

This does the following (but may not be limited to):
* Creates SSH setup for working with our GitHub.
* Clones common code repositories from our GitHub (depending on the selected `workflow`).
* Installs common useful apps (e.g. Visual Studio Code, Insomnia, etc.).
* Creates some useful bash aliases (e.g. `gco` for `git checkout`, etc.).
* Guides user through `~/.npmrc` setup
* Sets Chrome as default browser

**Note:** The above is for the default (ADT) workflow. To see what other workflows are available, run `sh setup.sh --help`

## Development

### Running Locally

To run the setup script (with the "adt" workflow):

```bash
sh setup.sh adt
```

To see usage:

```
sh setup.sh --help
```

### Testing

The best way to test this tool is to use a virtualization technology such as [UTM](https://mac.getutm.app/) (`brew install --cask utm`) to run a fresh MacOS virtual machine. The `setup.sh` script can then be copied over to the virtual machine, and executed.

If you use UTM, then you will need to create a mounted SMB volume called `share`, and then `sh ship-to-vm.sh` will automatically copy over `setup.sh` to the VM.

### Releasing

Before releasing, bump `VERSION` on L.3 of `setup.sh` to the appropriate version for your change.

---

## Why

This is a work-in-progress tool.

**Impetus**

At the moment, the setup process for dev machines at Vortexa mostly manual. New joiners must follow an assortment of Notion pages step-by-step. This has some cons:
* Slow
* Error-prone
* Often requires pod lead or team hand-holding at some point

**Aims**

Demonstrate the viability and pros of a tool that automates the setup process for a typical dev machine at Vortexa. This includes (but not necessarily limited to):
* Installing required apps such as nvm, vscode, insomnia, sops, aws-vpn-client, etc.
* Cloning core repositories most devs will need. For example, for an ADT new joiner, this could be `web`, `app-core`, `api`, `adt-publish-workers`, `adt-signals-api`, etc.
* Configuring any apps with required config
* Setting up env var files with minimum viable config, perhaps.

**OKRs:**

* Reduce time it takes a new joiner to get a key part of Vortexa (such as `web`) up and running locally from >1-2 hours to minutes (from when they receive their machine from IT)
* Reduce dependence on pod lead/team to help navigate through manual steps of any Notion pages

**Potential Challenges/Cons:**

* Maintenance burden
* Scope creep to do more and more setup tasks
* Original underlying manual process(es) are forgotten since a tool now automates it
