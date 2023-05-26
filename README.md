# vtx-setup-cli

---

Important note: At the current time, this is a highly experimental PoC.

**Impetus:** At the moment, the setup process for dev machines at Vortexa mostly manual. New joiners must follow an assortment of Notion pages step-by-step. This has some cons:
* Slow
* Error-prone
* Often requires pod lead or team hand-holding at some point

**Aims:** Demonstrate the viability and pros of a tool that automates the setup process for a typical dev machine at Vortexa. This includes (but not necessarily limited to):
* Installing required apps such as nvm, vscode, insomnia, sops, aws-vpn-client, etc.
* Cloning core repositories most devs will need. For example, for an ADT new joiner, this could be `web`, `app-core`, `api`, `adt-publish-workers`, `adt-signals-api`, etc.
* Configuring any apps with required config
* Setting up env var files with minimum viable config, perhaps.

**OKRs:**

* Reduce time it takes a new joiner to get a key part of Vortexa (such as `web`) up and running locally from >1-2 hours to minutes (from when they receive their machine from IT)
* Reduce dependence on pod lead/team to help navigate through manual steps of any Notion pages

**Potential Challenges/Cons:**

* Maintenance burden of an operational package
* Scope creep to do more and more setup tasks
* Original underlying manual process(es) are forgotten since a tool now automates it
* Current choice of golang is suboptimal for ADT (consider Rust?)
---

# Prerequisites

* [Go](https://go.dev/dl/)
* Add the following to your `~/.zprofile` file:
  ```bash
  # -- Go
  export GOPATH=$HOME/go
  export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
  ```

## Building

### Development

```
sh scripts/build-dev.sh
```

### Production

```
sh scripts/build.sh
```

## Running

The `setup` command can be built and ran as follows:

```bash
sh run-setup-dev.sh
```

## Development

The project's structure and build scripts are mostly based off of three sources:

* [project-layout](https://github.com/golang-standards/project-layout)
* [terraform](https://github.com/hashicorp/terraform)
* [velero](https://github.com/vmware-tanzu/velero)
